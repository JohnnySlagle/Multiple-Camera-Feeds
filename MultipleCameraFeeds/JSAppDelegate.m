//
//  JSAppDelegate.m
//  MultipleCameraFeeds
//
//  Created by Johnny Slagle on 7/27/14.
//  Copyright (c) 2014 Johnny Slagle. All rights reserved.
//

#import "JSAppDelegate.h"
#import "JSSolutionMenuViewController.h"

@implementation JSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    self.window.backgroundColor = [UIColor whiteColor];
    
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[[JSSolutionMenuViewController alloc] initWithStyle:UITableViewStyleGrouped]];
    
    [self.window makeKeyAndVisible];
    return YES;
}

@end
