@import Darwin;
@import CoreGraphics;
@import Cocoa;

typedef int        CGSConnection;
typedef long       CGSWindow;
typedef int        CGSValue;

extern CGSConnection CGSMainConnectionID(void);
extern OSStatus CGSSetWindowListBrightness(const CGSConnection cid, CGSWindow *wids, float *brightness, int count);
extern bool CGSIsMenuBarVisibleOnSpace(CGSConnection cid, long spaceNum);
extern long CGSManagedDisplayGetCurrentSpace(CGSConnection cid, CFStringRef uuid);
extern CFStringRef CGSCopyManagedDisplayForWindow(CGSConnection cid, CGSWindow wid);
