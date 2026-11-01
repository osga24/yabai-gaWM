#import <Cocoa/Cocoa.h>
#include <sys/file.h>
#include <unistd.h>
#include <spawn.h>
#include <sys/wait.h>
#include <poll.h>
#include <errno.h>
extern char **environ;
#ifndef YABAI_PATH
#define YABAI_PATH @"/opt/homebrew/bin/yabai"
#endif
static int code; static NSString *lastError;
static NSString *run(NSArray *args) {
 // posix_spawn + waitpid avoids NSTask's run-loop waiting between commands.
 int out[2],err[2];if(pipe(out)) {code=1;lastError=@"Cannot create output pipe.";return nil;}
 if(pipe(err)){close(out[0]);close(out[1]);code=1;lastError=@"Cannot create error pipe.";return nil;}
 posix_spawn_file_actions_t actions;posix_spawn_file_actions_init(&actions);
 posix_spawn_file_actions_adddup2(&actions,out[1],STDOUT_FILENO);
 posix_spawn_file_actions_adddup2(&actions,err[1],STDERR_FILENO);
 posix_spawn_file_actions_addclose(&actions,out[0]);posix_spawn_file_actions_addclose(&actions,err[0]);
 posix_spawn_file_actions_addclose(&actions,out[1]);posix_spawn_file_actions_addclose(&actions,err[1]);
 char **argv=calloc(args.count+3,sizeof(char*));argv[0]=strdup([YABAI_PATH fileSystemRepresentation]);argv[1]=strdup("-m");
 for(NSUInteger i=0;i<args.count;i++)argv[i+2]=strdup([args[i] UTF8String]);
 pid_t pid;int status=posix_spawn(&pid,argv[0],&actions,NULL,argv,environ);
 posix_spawn_file_actions_destroy(&actions);close(out[1]);close(err[1]);
 for(NSUInteger i=0;i<args.count+2;i++)free(argv[i]);free(argv);
 if(status){close(out[0]);close(err[0]);code=1;lastError=@(strerror(status));return nil;}
 NSMutableData *data=[NSMutableData data],*errors=[NSMutableData data];
 struct pollfd fds[2]={{out[0],POLLIN,0},{err[0],POLLIN,0}};int remaining=2;char buffer[8192];
 while(remaining){
  int ready=poll(fds,2,-1);if(ready<0){if(errno==EINTR)continue;break;}
  for(int i=0;i<2;i++)if(fds[i].fd>=0 && (fds[i].revents&(POLLIN|POLLHUP|POLLERR))){
   ssize_t n=read(fds[i].fd,buffer,sizeof(buffer));
   if(n>0)[(i==0?data:errors) appendBytes:buffer length:(NSUInteger)n];
   else if(n==0 || errno!=EINTR){close(fds[i].fd);fds[i].fd=-1;remaining--;}
  }
 }
 for(int i=0;i<2;i++)if(fds[i].fd>=0)close(fds[i].fd);
 while(waitpid(pid,&status,0)<0){if(errno!=EINTR){status=1;break;}}
 code=WIFEXITED(status)?WEXITSTATUS(status):1;
 lastError=[[NSString alloc]initWithData:errors encoding:NSUTF8StringEncoding];
 return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
static NSDictionary *query(NSArray *args){NSString *s=run(args);if(code || !s)return nil;id d=[NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];return [d isKindOfClass:[NSDictionary class]]?d:nil;}
static int fail(NSString *s){fprintf(stderr,"%s\n",s.UTF8String);return 1;}
int main(int argc,char **argv){@autoreleasepool{
 if(argc<2)return fail(@"Usage: wm-compat layout | resize <points> | display west|east|north|south");
 NSString *action=@(argv[1]);
 if([action isEqual:@"float"] || [action isEqual:@"target"]){
  pid_t pid=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
  if(pid<=0)return fail(@"Cannot identify the foreground application; no window changed.");
  NSString *raw=run(@[@"query",@"--windows"]);if(code || !raw)return fail(lastError?:@"Cannot query windows.");
  NSArray *windows=[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
  if(![windows isKindOfClass:[NSArray class]])return fail(@"Invalid window data; no window changed.");
  NSMutableArray *candidates=[NSMutableArray array];NSDictionary *focused=nil;
  for(NSDictionary *w in windows)if([w[@"pid"] intValue]==pid && ![w[@"is-minimized"] boolValue] && ![w[@"is-hidden"] boolValue] && [w[@"is-visible"] boolValue]){
   [candidates addObject:w];if([w[@"has-focus"] boolValue])focused=w;
  }
  // Ignore tiny utility/dialog windows when an ordinary resizable app window exists.
  NSMutableArray *standard=[NSMutableArray array];
  for(NSDictionary *candidate in candidates)
   if([candidate[@"subrole"] isEqual:@"AXStandardWindow"] && [candidate[@"can-resize"] boolValue]) [standard addObject:candidate];
  NSDictionary *target=nil;
  if(standard.count==1)target=standard[0];
  else if(standard.count>1){if(focused && [standard containsObject:focused])target=focused;}
  else target=candidates.count==1?candidates[0]:focused;
  if(!target)return fail(@"Foreground window is ambiguous or untracked; no window changed. Click its title bar and retry.");
  if([action isEqual:@"target"]){printf("%s window=%s pid=%d\n",[target[@"app"] UTF8String],[[target[@"id"] stringValue] UTF8String],pid);return 0;}
  run(@[@"window",[target[@"id"] stringValue],@"--toggle",@"float"]);
 }else if([action isEqual:@"layout"]){
  NSDictionary *s=query(@[@"query",@"--spaces",@"--space"]);if(!s)return fail(lastError?:@"No active Space.");
  run(@[@"space",@"--layout",[s[@"type"] isEqual:@"stack"]?@"bsp":@"stack"]);
 }else if([action isEqual:@"resize"]){
  if(argc!=3)return fail(@"resize requires a nonzero integer.");char *end;long delta=strtol(argv[2],&end,10);if(*end || delta==0 || labs(delta)>1000)return fail(@"Invalid resize step.");
  // Serialize resize operations so held/repeated keys cannot race each other.
  int lock=open("/private/tmp/osga-wm-resize.lock",O_CREAT|O_RDWR,0600);
  if(lock<0 || flock(lock,LOCK_EX|LOCK_NB)!=0)return fail(@"Resize already in progress.");
  NSDictionary *w=query(@[@"query",@"--windows",@"--window"]);if(!w)return fail(@"No focused window.");
  NSString *wid=[w[@"id"] stringValue];
  if([w[@"is-native-fullscreen"] boolValue])return fail(@"Exit native full screen before resizing.");
  if([w[@"has-fullscreen-zoom"] boolValue] || [w[@"has-parent-zoom"] boolValue])return fail(@"Exit window zoom before resizing.");
  NSString *handle=nil;BOOL horizontal=YES;
  if([w[@"is-floating"] boolValue])handle=[NSString stringWithFormat:@"bottom_right:%ld:%ld",delta,delta];
  else {
   NSDictionary *s=query(@[@"query",@"--spaces",@"--space",[w[@"space"] stringValue]]);if(!s)return fail(@"No Space details.");
   if(![s[@"type"] isEqual:@"bsp"])return fail(@"Resize requires BSP layout.");
   NSString *split=w[@"split-type"],*child=w[@"split-child"];
   if(![@[@"vertical",@"horizontal"] containsObject:split] || ![@[@"first_child",@"second_child"] containsObject:child])return fail(@"No adjacent tile boundary to resize.");
   horizontal=[split isEqual:@"vertical"];BOOL first=[child isEqual:@"first_child"];
   // Adjust only the shared parent boundary, never try a different axis.
   if(horizontal)handle=[NSString stringWithFormat:@"%@:%ld:0",first?@"right":@"left",first?delta:-delta];
   else handle=[NSString stringWithFormat:@"%@:0:%ld",first?@"bottom":@"top",first?delta:-delta];
  }
  NSDictionary *before=w[@"frame"];
  run(@[@"window",wid,@"--resize",handle]);if(code)return fail(lastError.length?lastError:@"No adjustable boundary.");
  double change=0;NSDictionary *after=nil;
  for(int attempt=0;attempt<4;attempt++) {
   if(attempt)usleep(5000);NSDictionary *updated=query(@[@"query",@"--windows",@"--window",wid]);if(!updated)return fail(@"Cannot verify resized window.");
   after=updated[@"frame"];
   if([w[@"is-floating"] boolValue])change=([after[@"w"] doubleValue]-[before[@"w"] doubleValue])+([after[@"h"] doubleValue]-[before[@"h"] doubleValue]);
   else {NSString *axis=horizontal?@"w":@"h";change=[after[axis] doubleValue]-[before[axis] doubleValue];}
   if(fabs(change)>0.5)break;
  }
  if(fabs(change)<=0.5)return fail(@"Size did not change: minimum/maximum size or an unavailable split boundary. No alternate direction was attempted.");
  if(change*delta<0) {
   // Unexpected backend behavior: restore using the exact inverse handle.
   NSArray *parts=[handle componentsSeparatedByString:@":"];
   NSString *inverse=[NSString stringWithFormat:@"%@:%ld:%ld",parts[0],-[parts[1] integerValue],-[parts[2] integerValue]];
   run(@[@"window",wid,@"--resize",inverse]);
   return fail(code?@"Unexpected resize direction; restore failed.":@"Unexpected resize direction; inverse operation sent. Stopped to avoid further resizing.");
  }
 }else if([action isEqual:@"display"]){
  if(argc!=3 || ![@[@"west",@"east",@"north",@"south"] containsObject:@(argv[2])])return fail(@"Invalid display direction.");
  run(@[@"window",@"--display",@(argv[2])]);if(code)return fail(lastError);
  NSDictionary *w=query(@[@"query",@"--windows",@"--window"]);if(!w)return fail(lastError?:@"No moved window.");
  NSDictionary *d=query(@[@"query",@"--displays",@"--display"]);if(!d)return fail(lastError?:@"No display details.");
  if(![w[@"display"] isEqual:d[@"index"]])run(@[@"display",@"--focus",[w[@"display"] stringValue]]);
 }else return fail(@"Unknown operation.");
 return code?fail(lastError.length?lastError:@"No adjustable boundary."):0;
}}
