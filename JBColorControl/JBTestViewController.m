//
//  JBTestViewController.m
//  JBColorControl
//
//  Created by Joachim Bondo on 30/07/2014.
//  Copyright (c) 2014 Joachim Bondo. All rights reserved.
//

#import "JBTestViewController.h"
#import "JBColorControl.h"

static NSString * const kSelectedColorKeyPath = @"selectedColorIndex";

@interface JBTestViewController ()
@property (nonatomic, strong) UIView *privateColorSwatchContainerView;
@property (nonatomic, strong) JBColorControl *privateColorControl;
@property (nonatomic, strong) JBColorControl *privateReadoutColorControl;
@end

#pragma mark -

@implementation JBTestViewController

- (instancetype)init {
	
	if ((self = [super init])) {
		
		self.title = NSStringFromClass ([JBColorControl class]);
		
		// Select first color.
		dispatch_async (dispatch_get_main_queue (), ^{
			self.privateColorControl.selectedColorIndex = 0;
		});
	}
	
	return self;
}

- (void)loadView {
	
	UIView *rootView = [[UIView alloc] init];
	rootView.backgroundColor = [UIColor whiteColor];
	
	// Enabled color control.
	
	JBColorControl *colorControl = [[JBColorControl alloc] init];
	[rootView addSubview:colorControl];
	[colorControl setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:colorControl attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:60]];
	[colorControl addConstraint:[NSLayoutConstraint constraintWithItem:colorControl attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:colorControl attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:colorControl attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:rootView attribute:NSLayoutAttributeCenterX multiplier:1 constant:64]];
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:colorControl attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:rootView attribute:NSLayoutAttributeCenterY multiplier:1 constant:10]];
	
	// Disabled color control.
	
	JBColorControl *readoutColorControl = [[JBColorControl alloc] init];
	[rootView insertSubview:readoutColorControl belowSubview:colorControl];
	[readoutColorControl setTranslatesAutoresizingMaskIntoConstraints:NO];
	
	// Size and position to the right of the read/write color control.
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:readoutColorControl attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:colorControl attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
	[readoutColorControl addConstraint:[NSLayoutConstraint constraintWithItem:readoutColorControl attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:readoutColorControl attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:readoutColorControl attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:rootView attribute:NSLayoutAttributeCenterX multiplier:1 constant:-64]];
	[rootView addConstraint:[NSLayoutConstraint constraintWithItem:readoutColorControl attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:colorControl attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
	
	// Toolbar containing swatches, centered.
	
	UIView *swatchContainerView = [[UIView alloc] initWithFrame:CGRectMake (0, 0, 280, 32)]; // Manual frame because it will live in a toolbar
	UIBarButtonItem *swatchToolbarItem = [[UIBarButtonItem alloc] initWithCustomView:swatchContainerView];
	UIBarButtonItem *flexibleSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	self.toolbarItems = @[flexibleSpaceItem, swatchToolbarItem, flexibleSpaceItem];
	self.navigationController.toolbarHidden = NO; // In case we are managed by a navigation controller
	
	UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector (JB_didTapSwatchContainer:)];
	[swatchContainerView addGestureRecognizer:tapRecognizer];
	
	// Set up ivars.
	
	self.privateColorSwatchContainerView = swatchContainerView;
	self.privateColorControl = colorControl;
	self.privateReadoutColorControl = readoutColorControl;
	self.view = rootView;
}

- (void)viewDidLoad {
	
	[super viewDidLoad];
	
	self.privateColorControl.enabled = YES;
	self.privateColorControl.selectableColors = @[
		[UIColor redColor],
		[UIColor blueColor],
		[UIColor greenColor],
		[UIColor yellowColor],
		[UIColor brownColor],
		[UIColor orangeColor],
		[UIColor purpleColor],
		[UIColor cyanColor],
		[UIColor magentaColor],
	];
	
	[self JB_loadSwatches];
	[self JB_layoutSwatches];
}

- (void)viewWillAppear:(BOOL)animated {
	self.navigationController.navigationBar.titleTextAttributes = @{
		NSFontAttributeName: [UIFont fontWithName:@"Courier" size:16],
	};
}

- (void)viewWillDisappear:(BOOL)animated {
	self.navigationController.navigationBar.titleTextAttributes = nil;
}

#pragma mark - Private Methods

- (void)JB_loadSwatches {
	
	UIView *containerView = self.privateColorSwatchContainerView;
	[containerView.subviews makeObjectsPerformSelector:@selector (removeFromSuperview)];
	
	for (UIColor *swatchColor in self.privateColorControl.selectableColors) {
		
		JBColorControl *swatch = [[JBColorControl alloc] init];
		swatch.enabled = NO;
		swatch.selectedColor = swatchColor;
		swatch.isAccessibilityElement = NO; // Use main color control directly, the container view interaction would offer an inferior experience anyway
		[swatch setTranslatesAutoresizingMaskIntoConstraints:NO];
		
		[containerView addSubview:swatch];
		
		[containerView addConstraint:[NSLayoutConstraint constraintWithItem:swatch attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:containerView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
	};
	
	[containerView layoutIfNeeded];
}

/// Size and distribute swatches horizontally.
- (void)JB_layoutSwatches {
	
	UIView *containerView = self.privateColorSwatchContainerView;
	
	CGFloat const padding = 8.0f;
	NSUInteger swatchCount = self.privateColorControl.selectableColors.count;
	CGFloat diameter = MIN (containerView.bounds.size.height, (containerView.bounds.size.width - (swatchCount - 1) * padding) / swatchCount);
	CGFloat contentWidth = swatchCount * diameter + (swatchCount - 1) * padding;
	CGFloat centerX = CGRectGetMidX (containerView.bounds) - (contentWidth - diameter) / 2.0f;
	CGRect swatchBounds = CGRectMake (0, 0, diameter, diameter);
	
	for (UIView *swatch in containerView.subviews) {
		
		CGPoint swatchCenter = swatch.center;
		swatchCenter.x = (CGFloat)round (centerX);
		
		swatch.center = swatchCenter;
		swatch.bounds = swatchBounds;
		
		centerX += diameter + padding;
	}
}

- (void)JB_didTapSwatchContainer:(UITapGestureRecognizer *)tapRecognizer {
	
	// Since the color controls are disabled, we're doing a manual hit detection.
	
	CGPoint tapPoint = [tapRecognizer locationInView:self.privateColorSwatchContainerView];
	CGFloat hitTargetRadius = self.privateColorSwatchContainerView.bounds.size.height / 2.0f;
	JBColorControl *tappedColorControl = nil;
	
	// We only need to check tap point's x value, and we'll make sure user can't tap between color controls.
	for (JBColorControl *colorControl in self.privateColorSwatchContainerView.subviews) {
		CGFloat rightTestX = CGRectGetMidX (colorControl.frame) + hitTargetRadius;
		if (tapPoint.x < rightTestX) {
			tappedColorControl = colorControl;
			break;
		}
	}
	
	if (tappedColorControl) {
		UIColor *selectedColor = tappedColorControl.selectableColors[0];
		[self.privateReadoutColorControl setSelectedColor:selectedColor animated:YES];
		[self.privateColorControl setSelectedColor:selectedColor animated:YES];
	}
}

@end