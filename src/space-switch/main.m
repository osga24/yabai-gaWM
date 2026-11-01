#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include "CStrafe.h"
#include <sys/file.h>
#include <unistd.h>
extern int CGSMainConnectionID(void);
extern CFArrayRef CGSCopyManagedDisplaySpaces(int, CFStringRef);
static NSArray *query(const char *command) {
 FILE *pipe=popen(command,"r");if(!pipe)return nil;
 NSMutableData *data=[NSMutableData data];char bytes[4096];size_t n;
 while((n=fread(bytes,1,sizeof(bytes),pipe))) [data appendBytes:bytes length:n];
 int status=pclose(pipe);if(status)return nil;
 return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}
static NSArray *topology(void) {
 static NSArray *displays=nil;
 if(!displays) displays=query("/opt/homebrew/bin/yabai -m query --displays");
 NSArray *windows=query("/opt/homebrew/bin/yabai -m query --spaces");
 NSMutableArray *result=[NSMutableArray array];
 for(NSDictionary *display in displays) {
  NSMutableArray *spaces=[NSMutableArray array];NSDictionary *current=nil;
  for(NSDictionary *sp in windows)if([sp[@"display"] isEqual:display[@"index"]]) {
   NSDictionary *entry=@{@"id64":sp[@"id"]};[spaces addObject:entry];
   if([sp[@"is-visible"] boolValue])current=entry;
  }
  [result addObject:@{@"Display Identifier":display[@"uuid"],@"Spaces":spaces,@"Current Space":current?:@{}}];
 }
 return result;
}
static int fail(NSString *message) {fprintf(stderr,"%s\n",message.UTF8String);return 1;}
static NSString *identifier(NSDictionary *d) {return d[@"Display Identifier"];}
int main(int argc,char **argv) {@autoreleasepool {

 if(argc==1 || (argc==2 && !strcmp(argv[1],"status"))) {
  printf("Accessibility: %s\n",AXIsProcessTrusted()?"granted":"not granted");
  printf("macOS 27 gesture payload: %s\n",strafe_uses_iohid_payload()?"enabled":"not required");
  return 0;
 }
 if(argc==2 && !strcmp(argv[1],"list")) {
  int n=0;for(NSDictionary *d in topology())for(NSDictionary *sp in d[@"Spaces"])printf("%d %llu %s\n",++n,[sp[@"id64"] unsignedLongLongValue],[identifier(d) UTF8String]);
  return 0;
 }
 char *end=NULL;long target=strtol(argv[1],&end,10);
 if(argc!=2 || !end || *end || target<1) return fail(@"Usage: space-switch <global desktop number> | status");
 if(!AXIsProcessTrusted()) return fail(@"Accessibility is not granted to SpaceSwitch. Add SpaceSwitch.app in System Settings > Privacy & Security > Accessibility. Language/speed is not the cause of this permission error.");
 int fd=open("/private/tmp/spacetill-native-switch.lock",O_CREAT|O_RDWR,0600);
 if(fd<0 || flock(fd,LOCK_EX|LOCK_NB)<0) return fail(@"A desktop switch is already running; retry after it finishes.");
 NSArray *all=topology();NSDictionary *destination=nil,*destDisplay=nil;NSInteger position=0,index=0;
 for(NSDictionary *display in all) {
  NSArray *spaces=display[@"Spaces"];
  for(NSInteger i=0;i<(NSInteger)spaces.count;i++) {
   index++;if(index==target){destination=spaces[i];destDisplay=display;position=i;break;}
  }
  if(destination)break;
 }
 if(!destination)return fail(@"Target desktop does not exist. Check yabai -m query --spaces after connecting/disconnecting displays.");
 uint64_t wanted=[destination[@"id64"] unsignedLongLongValue];
 NSString *uuid=identifier(destDisplay);CGDirectDisplayID active[32];uint32_t count=0;
 CGGetActiveDisplayList(32,active,&count);BOOL matched=NO;
 for(uint32_t i=0;i<count;i++) {
  CFUUIDRef u=CGDisplayCreateUUIDFromDisplayID(active[i]);
  NSString *s=u?CFBridgingRelease(CFUUIDCreateString(NULL,u)):nil;if(u)CFRelease(u);
  if([s isEqualToString:uuid] || ([uuid isEqualToString:@"Main"] && active[i]==CGMainDisplayID())) {
   CGRect f=CGDisplayBounds(active[i]);CGWarpMouseCursorPosition(CGPointMake(CGRectGetMidX(f),CGRectGetMidY(f)));matched=YES;break;
  }
 }
 if(!matched)return fail(@"Target display was disconnected; retry with the new desktop numbering.");
 for(NSUInteger step=0;step<32;step++) {
  NSDictionary *currentDisplay=nil;
  for(NSDictionary *d in topology())if([identifier(d) isEqualToString:uuid]){currentDisplay=d;break;}
  if(!currentDisplay)return fail(@"Display topology changed during switching.");
  uint64_t current=[currentDisplay[@"Current Space"][@"id64"] unsignedLongLongValue];
  if(current==wanted)return 0;
  NSArray *spaces=currentDisplay[@"Spaces"];NSInteger currentPos=-1;position=-1;
  for(NSInteger i=0;i<(NSInteger)spaces.count;i++) {uint64_t sid=[spaces[i][@"id64"] unsignedLongLongValue];if(sid==current)currentPos=i;if(sid==wanted)position=i;}
  if(currentPos<0 || position<0)return fail(@"Desktop topology changed during switching.");
  if(!strafe_post_switch_gesture(position>currentPos?StrafeDirectionRight:StrafeDirectionLeft,2000.0))return fail(@"Could not construct the synthetic macOS gesture.");
  BOOL changed=NO;
  for(int retry=0;retry<80;retry++) {
   usleep(10000);
   for(NSDictionary *d in topology())if([identifier(d) isEqualToString:uuid] && [d[@"Current Space"][@"id64"] unsignedLongLongValue]!=current){changed=YES;break;}
   if(changed)break;
  }
  if(!changed)return fail(@"Gesture posted, but desktop did not change. Check Accessibility, close Mission Control, and verify macOS compatibility; this is not a Python performance issue.");
 }
 return fail(@"Target desktop was not reached.");
}}
