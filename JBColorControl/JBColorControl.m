//
//  JBColorControl.m
//
//  Created by Joachim Bondo on 19/05/2014.
//  Copyright (c) 2014 Cocoa Stuff. All rights reserved.
//

#import "JBColorControl.h"


typedef struct {
	CGFloat diameter;
	CGFloat distance;
} JBPrivateColorControlGeometry;

static CGSize const kMinimumHitTargetSize = {48, 48}; // In case the bounds size is smaller, this is the hit target size that will be used
static NSString * const kSelectedColorIndexKeyPath = @"selectedColorIndex"; // Used for both self and selected layer
static NSString * const kSelectedColorKeyPath = @"selectedColor";

/// Computes a suitable stroke color from a given fill color.
static UIColor* StrokeColorFromFillColor (UIColor* fillColor);

#pragma mark -

@interface JBColorControl () <UIScrollViewDelegate>

/// The scroll view, containing the two color swatch layers, handling the user interaction.
@property (nonatomic, strong) UIScrollView *privateScrollView;

/// Cached geometry.
@property (nonatomic, assign) JBPrivateColorControlGeometry privateGeometry;

@end

#pragma mark -

@implementation JBColorControl

- (id)initWithFrame:(CGRect)frame {
	
	if ((self = [super initWithFrame:frame])) {
		
		self.layer.masksToBounds = YES;
		
		// Set default values.
		
		self.enabled = NO; // To set the border color and keep view hierarchy simple until we might be enabled
		self.layer.borderWidth = 1.0f / [[UIScreen mainScreen] scale]; // 1 px hairline
		self.selectedColorIndex = NSNotFound;
	}
	
	return self;
}

- (void)setEnabled:(BOOL)enabled {
	
	[super setEnabled:enabled];
	
	if (enabled) {
		[self JB_expandViewHierarchy];
	} else {
		[self JB_collapseViewHierarchy];
	}
	
	[self JB_updateAppearanceAnimated:NO];
}

- (void)setBounds:(CGRect)bounds {
	
	// Make sure we're circular.
	CGFloat diameter = MAX (bounds.size.width, bounds.size.height);
	self.layer.cornerRadius = diameter / 2.0f;
	bounds.size = CGSizeMake (diameter, diameter);
	
	// Cache geometry.
	JBPrivateColorControlGeometry geometry;
	geometry.diameter = diameter;
	self.privateGeometry = geometry;
	
	[super setBounds:bounds];
}

// Size and position private scroll view, size swatch layers.
- (void)layoutSubviews {
	
	[super layoutSubviews];
	
	if (!self.enabled || self.privateGeometry.diameter == self.privateScrollView.frame.size.width) {
		return; // No subviews or no change in size
	}
	
	CGFloat radius = self.privateGeometry.diameter / 2.0f;
	
	for (CALayer *swatchLayer in self.privateScrollView.layer.sublayers) {
		swatchLayer.bounds = self.bounds;
		swatchLayer.cornerRadius = radius;
	}
	
	self.privateScrollView.frame = self.bounds;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	
	// Determine how much we must inset (outset, really) on each dimension in order to satisfy the minimum hit target size.
	CGFloat deltaX = MAX (kMinimumHitTargetSize.width - self.bounds.size.width, 0) / 2.0f;
	CGFloat deltaY = MAX (kMinimumHitTargetSize.height - self.bounds.size.height, 0) / 2.0f;
	CGRect hitFrame = CGRectInset (self.bounds, -deltaX, -deltaY);
	
	return CGRectContainsPoint (hitFrame, point);
}

#pragma mark Color Accessors

- (void)setSelectedColorIndex:(NSUInteger)selectedColorIndex {
	[self setSelectedColorIndex:selectedColorIndex animated:NO];
}

/// Designated selectedColor/selectedColorIndex setter.
- (void)setSelectedColorIndex:(NSUInteger)selectedColorIndex animated:(BOOL)animated {
	
	_selectedColorIndex = selectedColorIndex;
	
	[self JB_updateAppearanceAnimated:animated];
}

- (void)setSelectedColor:(UIColor *)selectedColor {
	[self setSelectedColor:selectedColor animated:NO];
}

- (void)setSelectedColor:(UIColor *)color animated:(BOOL)animated {
	
	NSUInteger selectedIndex = [self.selectableColors indexOfObject:color];
	
	if (color && (!self.selectableColors || selectedIndex == NSNotFound)) {
		self.selectableColors = @[color];
		selectedIndex = 0;
	}
	
	[self setSelectedColorIndex:selectedIndex animated:animated];
}

- (UIColor *)selectedColor {
	UIColor *selectedColor = (self.selectedColorIndex < [self.selectableColors count] ? self.selectableColors[self.selectedColorIndex] : nil);
	return selectedColor;
}

#pragma mark - Private Methods

- (void)JB_updateAppearanceAnimated:(BOOL)animated {
	
	UIColor *strokeColor;
	UIColor *fillColor;
	
	if (self.enabled) {
		fillColor = [UIColor clearColor]; // Color is set by the visible swatch layer
		strokeColor = [UIColor colorWithWhite:0.25f alpha:1];
	} else {
		fillColor = (self.selectedColor ?: [UIColor clearColor]);
		strokeColor = StrokeColorFromFillColor (fillColor);
	}
	
	if (animated) {
		
		CALayer *presentationLayer = self.layer.presentationLayer;
		
		CABasicAnimation *crossFadeFill = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
		crossFadeFill.fromValue = (__bridge id)(presentationLayer.backgroundColor);
		crossFadeFill.toValue = (__bridge id)(fillColor.CGColor);
		[self.layer addAnimation:crossFadeFill forKey:crossFadeFill.keyPath];
		
		CABasicAnimation *crossFadeStroke = [CABasicAnimation animationWithKeyPath:@"borderColor"];
		crossFadeStroke.fromValue = (__bridge id)(presentationLayer.borderColor);
		crossFadeStroke.toValue = (__bridge id)(strokeColor.CGColor);
		[self.layer addAnimation:crossFadeStroke forKey:crossFadeStroke.keyPath];
	}
	
	self.layer.backgroundColor = fillColor.CGColor;
	self.layer.borderColor = strokeColor.CGColor;
}

- (void)JB_collapseViewHierarchy {
	
	[self.privateScrollView removeFromSuperview];
	
	self.privateScrollView = nil;
}

- (void)JB_expandViewHierarchy {
	
	if (!self.privateScrollView) {
		
		self.privateScrollView = [[UIScrollView alloc] init];
		
		self.privateScrollView.backgroundColor = [UIColor clearColor];
		self.privateScrollView.clipsToBounds = YES;
		self.privateScrollView.showsHorizontalScrollIndicator = NO;
		self.privateScrollView.showsVerticalScrollIndicator = NO;
		self.privateScrollView.bounces = NO; // Will never reach edge anyway
		self.privateScrollView.scrollsToTop = NO;
		self.privateScrollView.delegate = self;
		
		[self addSubview:self.privateScrollView];
		
		[self setNeedsLayout];
	}
}

@end

#pragma mark - Utility Functions

static UIColor* StrokeColorFromFillColor (UIColor* fillColor) {
	
	CGFloat hue, saturation, brightness, alpha;
	
	[fillColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
	
	if (alpha < 0.01f) { // Covers both nil and clear colors
		return [UIColor colorWithWhite:0.75f alpha:1]; // Could use a UI_APPEARANCE_SELECTOR property?
	}
	
	if (brightness < 0.5f) {
		brightness = MIN (brightness * 1.50f, 1);
	} else {
		brightness = MAX (brightness * 0.75f, 0);
	}
	
	return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}
