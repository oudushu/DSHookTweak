/* How to Hook with Logos
Hooks are written with syntax similar to that of an Objective-C @implementation.
You don't need to #include <substrate.h>, it will be done automatically, as will
the generation of a class list and an automatic constructor.

%hook ClassName

// Hooking a class method
+ (id)sharedInstance {
	return %orig;
}

// Hooking an instance method with an argument.
- (void)messageName:(int)argument {
	%log; // Write a message about this call, including its class, name and arguments, to the system log.

	%orig; // Call through to the original function with its original arguments.
	%orig(nil); // Call through to the original function with a custom argument.

	// If you use %orig(), you MUST supply all arguments (except for self and _cmd, the automatically generated ones.)
}

// Hooking an instance method with no arguments.
- (id)noArguments {
	%log;
	id awesome = %orig;
	[awesome doSomethingElse];

	return awesome;
}

// Always make sure you clean up after yourself; Not doing so could have grave consequences!
%end
*/


// __attribute__((constructor))
// static void initialize_tweak() {
//     // 在应用启动时立即执行，但我们要延迟 5 秒显示弹窗
//     flog(@"MyTweak has been initialized.");
//     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
//         // 创建并显示弹窗
//         UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Hello, World!"
//                                                                        message:@"This is a popup after 5 seconds."
//                                                                 preferredStyle:UIAlertControllerStyleAlert];

//         UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
//         [alert addAction:okAction];

//         // 获取当前的根视图控制器并展示弹窗
//         UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
//         UIViewController *rootViewController = keyWindow.rootViewController;
//         [rootViewController presentViewController:alert animated:YES completion:nil];
//     });
// }


#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "FLEX.h"
#import "CocoaLumberjack.h"

void flog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *logStr = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DDLog addLogger:[DDOSLogger sharedInstance]]; // Uses os_log

        DDFileLogger *fileLogger = [[DDFileLogger alloc] init]; // File Logger
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        [fileLogger setMaximumFileSize:50 * 1024 * 1024];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss:SSS"];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setCalendar:[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]];
        fileLogger->_logFormatter = [[DDLogFileFormatterDefault alloc] initWithDateFormatter:dateFormatter];
        [DDLog addLogger:fileLogger];
    });

    [DDLog log:NO level:DDLogLevelError flag:DDLogFlagError context:0 file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__ tag:nil format:@"[DSHook] %@", logStr];
	// NSLog(@"[DSHook] %@", logStr);
}

void dumpAllClassesAndMethods() {
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;

    if (numClasses > 0) {
		flog(@"start dump");
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);

        NSMutableString *output = [NSMutableString string];

        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            NSString *className = NSStringFromClass(cls);
            [output appendFormat:@"%@", className];

			Class superClass = class_getSuperclass(cls);
            if (superClass) {
                NSString *superClassName = NSStringFromClass(superClass);
                [output appendFormat:@" : %@\n", superClassName];
            } else {
                [output appendFormat:@"\n"];
            }

            unsigned int propertyCount;
            objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);

            for (unsigned int j = 0; j < propertyCount; j++) {
                objc_property_t property = properties[j];
                const char *propertyName = property_getName(property);
                [output appendFormat:@"    P: %s\n", propertyName];
            }

            free(properties);

			unsigned int ivarCount;
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);

            for (unsigned int j = 0; j < ivarCount; j++) {
                Ivar ivar = ivars[j];
                const char *ivarName = ivar_getName(ivar);
                [output appendFormat:@"    I: %s\n", ivarName];
            }

            free(ivars);

            unsigned int methodCount;
            Method *methods = class_copyMethodList(cls, &methodCount);

            for (unsigned int j = 0; j < methodCount; j++) {
                Method method = methods[j];
                SEL selector = method_getName(method);
                NSString *methodName = NSStringFromSelector(selector);
                [output appendFormat:@"    M: %@\n", methodName];
            }

            free(methods);
        }

        free(classes);

		flog(@"start write file");

        // 将结果写入文件
		NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString *filePath = [documentsPath stringByAppendingPathComponent:@"CachesClassesAndMethods.txt"];
        [output writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];

		flog(@"dump succeed");

		dispatch_async(dispatch_get_main_queue(), ^{
			NSURL *shareUrl = [NSURL fileURLWithPath:filePath];

			UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareUrl] applicationActivities:nil];
			activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
				flog(@"shared succeed");
			};
			[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:activityVC animated:YES completion:nil];
		});
    }
}

void sharedLogs() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *path = [paths objectAtIndex:0];
	path = [path stringByAppendingPathComponent:@"Caches"];
	path = [path stringByAppendingPathComponent:@"Logs"];
	NSURL *shareUrl = [NSURL fileURLWithPath:path];
	
	UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[shareUrl] applicationActivities:nil];
	activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
	};
	[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:activityVC animated:YES completion:nil];
}

void deleteLogs() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	NSString *path = [paths objectAtIndex:0];
	path = [path stringByAppendingPathComponent:@"Caches"];
	path = [path stringByAppendingPathComponent:@"Logs"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:path error:nil];
}

__attribute__((constructor))
static void initialize_tweak() {
    flog(@"Tweaked");
}

%hook UIViewController

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
																message:nil
														preferredStyle:UIAlertControllerStyleAlert];

		[alert addAction:[UIAlertAction actionWithTitle:@"Show FLEX" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[FLEXManager sharedManager] showExplorer];
		}]];

		[alert addAction:[UIAlertAction actionWithTitle:@"Dump Symbols" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			dumpAllClassesAndMethods();
		}]];

		[alert addAction:[UIAlertAction actionWithTitle:@"Airdrop Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			sharedLogs();
		}]];

        [alert addAction:[UIAlertAction actionWithTitle:@"Delete Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			deleteLogs();
		}]];

        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *rootViewController = keyWindow.rootViewController;
        [rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

%end

@implementation NSObject (DS)

NSString *CMTimeToString(CMTime time) {
    NSString *timeStr = (__bridge NSString *)CMTimeCopyDescription(kCFAllocatorDefault, time);
    return timeStr;
}

- (NSDictionary *)ds_getAllIvarsAndValues {
    NSMutableArray *arr = [NSMutableArray array];
    unsigned int count = 0;
    Ivar *propertyList = class_copyIvarList([self class], &count);
    for (int i =0; i<count; i++) {
        Ivar property = propertyList[i];
        const char *name = ivar_getName(property);
        NSString *nameStr = [[NSString alloc] initWithUTF8String:name];
        [arr addObject:nameStr];
    }
    free(propertyList);
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [arr enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        @try {
            id value = [self valueForKeyPath:obj];
            if ([value isKindOfClass:[NSValue class]]) {
                NSValue *val = value;
                if (strcmp(val.objCType, "{?=qiIq}") == 0) {
                    dict[obj] = CMTimeToString(val.CMTimeValue);
                } else if (strcmp(val.objCType, "{?=fff}") == 0) {
                    dict[obj] = value;
                } else {
                    dict[obj] = value;
                }
            } else {
                dict[obj] = value;
            }
        } @catch (NSException *exception) {
            
        } @finally {
            
        }
    }];
    
    return [dict copy];
}

@end


void printOutput(AVCaptureOutput *arg1, CMSampleBufferRef arg2, AVCaptureConnection *arg3) {
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
    
    AVCaptureDeviceInput *input = (AVCaptureDeviceInput *)arg3.inputPorts.firstObject.input;
    AVCaptureDevice *device = input.device;
    
    NSDictionary *outputInternal = [(NSObject *)[arg1 valueForKey:@"_internal"] ds_getAllIvarsAndValues];
    NSDictionary *connectionInternal = [(NSObject *)[arg3 valueForKey:@"_internal"] ds_getAllIvarsAndValues];
    NSDictionary *captureDevice = [device ds_getAllIvarsAndValues];
    
    NSMutableDictionary *outputDict = [NSMutableDictionary dictionary];
    outputDict[@"AVCaptureVideoDataOutputInternal"] = outputInternal;
    outputDict[@"AVCaptureConnectionInternal"] = connectionInternal;
    outputDict[@"AVCaptureDevice"] = captureDevice;
    
	flog(@"outputDict:%@", outputDict);
    
    // CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(arg2);
    
    // CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    // void *yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    // size_t yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    // size_t uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    // size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    // size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    
    // NSData *data = [NSData dataWithBytes:yBaseAddress length:yStride * yHeight + uvStride * uvHeight];
    
    // CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // NSDictionary *videoSettings = [(AVCaptureVideoDataOutput *)arg1 videoSettings];
    
    // CVImageBufferRef pixelBuffer1 = CMSampleBufferGetImageBuffer(arg2);
    
    // CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer1];
    
    // CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    // CGImageRef videoImage = [temporaryContext
    //                          createCGImage:ciImage
    //                          fromRect:CGRectMake(0, 0,
    //                                              CVPixelBufferGetWidth(pixelBuffer1),
    //                                              CVPixelBufferGetHeight(pixelBuffer1))];
    
    // UIImage *uiImage = [UIImage imageWithCGImage:videoImage];
    // CGImageRelease(videoImage);
    
    // NSData *imagedata = UIImagePNGRepresentation(uiImage);
    
    // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //     writeDataToFile(imagedata, [NSString stringWithFormat:@"data_%lld.png", (long long)current]);
        
    //     writeDictToFile(outputDict, [NSString stringWithFormat:@"info_%lld.txt", (long long)current]);
    //     flog(@"outputDict %@",outputDict);
        
    //     writeDataToFile(data, [NSString stringWithFormat:@"data_w_%zu_h_%zu_%@_%lld.yuv", yStride, yHeight, changeToTypeStr([videoSettings[@"PixelFormatType"] intValue]), (long long)current]);
    // });
}

%hook AVCaptureFigVideoDevice

- (void)setVideoZoomFactor:(CGFloat)factor {
    %orig(factor);
    flog(@"Device: %@, Video zoom factor was set to: %f", self, factor);
}

- (void)automaticallyEnablesLowLightBoostWhenAvailable:(BOOL)enable {
    %orig(enable);
    flog(@"Device: %@, automaticallyEnablesLowLightBoostWhenAvailable", self, enable);
}

- (void)lowLightBoostEnabled:(BOOL)enable {
    %orig(enable);
    flog(@"Device: %@, lowLightBoostEnabled", self, enable);
}

%end

%hook IESMMCaptureKit

- (instancetype)init {
	flog(@"IESMMCaptureKit init");
	return %orig;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    %orig(output, sampleBuffer, connection);

	// printOutput(output, sampleBuffer, connection);
	flog(@"didOutputSampleBuffer");
}

%end

%hook AVCaptureVideoDataOutput
// - (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
//     %orig(sampleBufferDelegate, sampleBufferCallbackQueue);
//     flog(@"setSampleBufferDelegate: %@", sampleBufferDelegate);
// }

- (void)_processSampleBuffer:(CMSampleBufferRef)buffer {
    %orig(buffer);

    static NSDate *lastLogDate = nil;
    
    NSDate *currentDate = [NSDate date];
    if (!lastLogDate || [currentDate timeIntervalSinceDate:lastLogDate] >= 5.0) {
        flog(@"delegate: %@ _processSampleBuffer: %@", [self sampleBufferDelegate], buffer);
        lastLogDate = currentDate;

        // AVCaptureConnection *connection = [self connectionWithMediaType:AVMediaTypeVideo];    
        // [[self sampleBufferDelegate] captureOutput:self didOutputSampleBuffer:buffer fromConnection:connection];
    }

}
%end

%hook AWEHPTopTabItemView
- (instancetype)init {
	flog(@"AWEHPTopTabItemView init");
	return %orig();
}
%end

%hook AWEFeedViewCell
- (instancetype)init {
	flog(@"AWEFeedViewCell init");
	return %orig();
}
%end

%hook AWEHPTopBarCTAContainer
- (instancetype)init {
	flog(@"AWEHPTopBarCTAContainer init");
	return %orig();
}
%end