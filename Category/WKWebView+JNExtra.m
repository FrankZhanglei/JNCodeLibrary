//
//  WKWebView+JNExtra.m
//  JNCodeLibrary
//
//  Created by xuning on 2018/5/21.
//  Copyright © 2018年 Hsu. All rights reserved.
//

#import "WKWebView+JNExtra.h"
#import <objc/runtime.h>

@implementation WKWebView (JNExtra)


+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(loadRequest:);
        SEL swizzledSelector = @selector(post_loadRequest:);
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

-(WKNavigation *)post_loadRequest:(NSURLRequest *)request {
    
    if ([[request.HTTPMethod uppercaseString] isEqualToString:@"POST"]){
        NSString *url = request.URL.absoluteString;
        NSString *params = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        // 方式一:下面注释要打开  方式二:注释掉
        //
        //        if ([params containsString:@"="]) {
        //            params = [params stringByReplacingOccurrencesOfString:@"=" withString:@"\":\""];
        //            params = [params stringByReplacingOccurrencesOfString:@"&" withString:@"\",\""];
        //            params = [NSString stringWithFormat:@"{\"%@\"}", params];
        //        }else{
        //            params = @"{}";
        //        }
        NSString *postJavaScript = [NSString stringWithFormat:@"\
                                    var url = '%@';\
                                    var params = %@;\
                                    var form = document.createElement('form');\
                                    form.setAttribute('method', 'post');\
                                    form.setAttribute('action', url);\
                                    for(var key in params) {\
                                    if(params.hasOwnProperty(key)) {\
                                    var hiddenField = document.createElement('input');\
                                    hiddenField.setAttribute('type', 'hidden');\
                                    hiddenField.setAttribute('name', key);\
                                    hiddenField.setAttribute('value', params[key]);\
                                    form.appendChild(hiddenField);\
                                    }\
                                    }\
                                    document.body.appendChild(form);\
                                    form.submit();", url, params];
        //        __block id result = nil;
        //        __block BOOL isExecuted = NO;
        __weak typeof(self) wself = self;
        [self evaluateJavaScript:postJavaScript completionHandler:^(id object, NSError * _Nullable error) {
            if (error && [wself.navigationDelegate respondsToSelector:@selector(webView:didFailProvisionalNavigation:withError:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [wself.navigationDelegate webView:wself didFailProvisionalNavigation:nil withError:error];
                });
            }
            //            result = object;
            //            isExecuted = YES;
        }];
        //        while (isExecuted == NO) {
        //            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        //        }
        return nil;
    }else{
        return [self post_loadRequest:request];
    }
}

@end
