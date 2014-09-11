//
//  JBAppDelegate.m
//  JBColorControl
//
//  Created by Joachim Bondo on 30/07/2014.
//  Copyright (c) 2014 Joachim Bondo. All rights reserved.
//

#import "JBAppDelegate.h"
#import "JBTestViewController.h"

@interface JBAppDelegate ()
@property (nonatomic, strong) UIWindow *privateWindow;
@end

#pragma mark -

@implementation JBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	
	self.privateWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.privateWindow.backgroundColor = [UIColor blackColor];
	self.privateWindow.rootViewController = [self JB_configuredNavigationController];
	self.privateWindow.tintColor = [UIColor orangeColor];
	
	[self.privateWindow makeKeyAndVisible];
	
	return YES;
}

#pragma mark - Private Methods

- (UIViewController *)JB_configuredNavigationController {
	
	JBTestViewController *testViewController = [[JBTestViewController alloc] init];
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:testViewController];
	
	return navigationController;
}

@end
