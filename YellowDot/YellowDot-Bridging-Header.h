@import Darwin;
@import CoreGraphics;
@import Cocoa;

typedef int        CGSConnection;
typedef long       CGSWindow;
typedef int        CGSValue;

extern CGSConnection CGSMainConnectionID(void);
extern OSStatus CGSSetWindowListBrightness(const CGSConnection cid, CGSWindow *wids, float *brightness, int count);

