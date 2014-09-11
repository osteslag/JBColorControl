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
static CGFloat const kColorSwatchPaddingFractionOfDiameter = 0.2f; // Blank space between swatch layers
static CGFloat const kMaximumScrollDistance = 8192; // More than the maximum distance the scroll view can be set to travel when swiping
static NSString * const kSelectedColorIndexKeyPath = @"selectedColorIndex"; // Used for both self and selected layer
static NSString * const kSelectedColorKeyPath = @"selectedColor";

/// Computes a suitable stroke color from a given fill color.
static UIColor* StrokeColorFromFillColor (UIColor* fillColor);

#pragma mark -

@interface JBColorControl () <UIScrollViewDelegate>

/// The scroll view, containing the two color swatch layers, handling the user interaction.
@property (nonatomic, strong) UIScrollView *privateScrollView;

/// The layer representing the selected (most visible) color.
@property (nonatomic, strong) CALayer *privateSelectedLayer;

/// The layer representing the next or previous (not so visible) color.
@property (nonatomic, strong) CALayer *privateSecondaryLayer;

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
		
		self.isAccessibilityElement = YES;
		self.accessibilityLabel = NSLocalizedString (@"Color", @"Default/generic Accessibility Label for a color control.");
	}
	
	return self;
}

- (void)setEnabled:(BOOL)enabled {
	
	[super setEnabled:enabled];
	
	if (enabled) {
		[self JB_expandViewHierarchy];
		[self JB_scrollToColorSwatchLayerAtIndex:self.selectedColorIndex animated:NO];
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
	geometry.distance = (CGFloat)round (diameter * (1 + kColorSwatchPaddingFractionOfDiameter));
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
	self.privateScrollView.contentSize = CGSizeMake (self.privateGeometry.diameter, kMaximumScrollDistance * 2); // Enough for "infinite" scrolling
	
	[self JB_adjustContentOffsetIfNecessary]; // Needed for the first layout pass when we are at offset zero
	[self JB_scrollToColorSwatchLayerAtIndex:self.selectedColorIndex animated:NO];
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
	
	[self willChangeValueForKey:kSelectedColorIndexKeyPath];
	_selectedColorIndex = selectedColorIndex;
	[self didChangeValueForKey:kSelectedColorIndexKeyPath];
	
	if (self.enabled) {
		[self JB_scrollToColorSwatchLayerAtIndex:selectedColorIndex animated:animated];
	} else {
		[self JB_updateAppearanceAnimated:animated];
	}
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

#pragma mark - NSKeyValueObserving Protocol

/// Whenever we are changing selectedColorIndex, selectedColor is also affected.
+ (NSSet *)keyPathsForValuesAffectingSelectedColor {
	return [NSSet setWithObject:kSelectedColorIndexKeyPath];
}

// Because we are implementing animated: versions of the color setters, and the base setters ultimately call the "designated" setter with the animated: parameter, -setSelectedColorIndex:animated:, *and* these animated: versions can be called independently, we have to manually notify in order to avoid sometimes notifying twice (i.e., when calling base setters).

+ (BOOL)automaticallyNotifiesObserversOfSelectedColorIndex {
	return NO;
}

+ (BOOL)automaticallyNotifiesObserversOfSelectedColor {
	return NO;
}

#pragma mark UIScrollViewDelegate Protocol

// We shouldn't adjust content offset while scrolling because it would mess up how the scroll view would interpret the offset returned in -scrollViewWillEndDragging:withVelocity:targetContentOffset: and how it would come to rest.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
	[self JB_updateColorSwatchLayers];
}

// Possibly center the content so that the user can't keep scrolling all the way to the edge.
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self JB_adjustContentOffsetIfNecessary];
}

/// Computes the color swatch layer closest to the targetContentOffset and adjusts it to align with the layer.
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
	NSUInteger targetIndex = [self JB_mostVisibleColorIndexAtContentOffset:*targetContentOffset];
	*targetContentOffset = [self JB_contentOffsetForColorIndex:targetIndex nearest:*targetContentOffset];
}

/// The catch-all method for user-selection of new values.
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	
	[self JB_adjustContentOffsetIfNecessary];
	
	NSUInteger selectedColorIndex = [[self.privateSelectedLayer valueForKeyPath:kSelectedColorIndexKeyPath] unsignedIntegerValue];
	if (selectedColorIndex != self.selectedColorIndex) {
		self.selectedColorIndex = selectedColorIndex;
		[self sendActionsForControlEvents:UIControlEventValueChanged];
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate {
	if (!willDecelerate) {
		[self scrollViewDidEndDecelerating:scrollView];
	}
}

#pragma mark UIAccessibility Protocol

// The accessibility aspects that do not need to be customized or maintained with Voice Over turned off are implemented here.

- (NSString *)accessibilityValue {
	
	NSString *accessibilityValue;
	NSUInteger selectedColorIndex = self.selectedColorIndex;
	
	if (selectedColorIndex == NSNotFound) {
		accessibilityValue = (self.localizedAccessibilityNoSelectionValue ?: NSLocalizedString (@"No selection", @"Default Accessibility Value for no selection."));
	} else {
		if (self.localizedAccessibilityValues) {
			NSAssert (self.localizedAccessibilityValues.count == self.selectableColors.count, @"There must be an equal number of elements in the selectableColors and localizedAccessibilityValues arrays.");
			accessibilityValue = self.localizedAccessibilityValues[selectedColorIndex];
		} else {
			accessibilityValue = [NSString stringWithFormat:@"%lu", (unsigned long)selectedColorIndex]; // Default Accessibility Value
		}
	}
	
	return accessibilityValue;
}

- (UIAccessibilityTraits)accessibilityTraits {
	return (self.enabled ? UIAccessibilityTraitAdjustable : UIAccessibilityTraitNotEnabled);
}

- (void)accessibilityIncrement {
	[self JB_selectNextElementInDirection:UIAccessibilityScrollDirectionNext animated:YES];
}

- (void)accessibilityDecrement {
	[self JB_selectNextElementInDirection:UIAccessibilityScrollDirectionPrevious animated:YES];
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
	
	self.privateSelectedLayer = nil;
	self.privateSecondaryLayer = nil;
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
		
		self.privateSelectedLayer = [CALayer layer];
		self.privateSecondaryLayer = [CALayer layer];
		
		[self.privateScrollView.layer addSublayer:self.privateSelectedLayer];
		[self.privateScrollView.layer addSublayer:self.privateSecondaryLayer];
		[self addSubview:self.privateScrollView];
		
		[self setNeedsLayout];
	}
}

/** Offset content if we're too far from the center.
 @discussion The reason why we re-center rather early is that if the user gives the scroll view a fast swipe, there should be enough content to scroll to rest -- without having to re-center (which would halt the scrolling, I assume). Re-centering (and rearranging the content) will give the illusion of infinite scrolling.
 @note This method assumes that the scroll view is already "on track", meaning that we can (and must) adjust the content offset by a whole number of "full paletttes" (representations of all colors).
 */
- (void)JB_adjustContentOffsetIfNecessary {
	
	CGPoint contentOffset = self.privateScrollView.contentOffset;
	CGFloat contentHeight = self.privateScrollView.contentSize.height;
	CGFloat distanceToContentCenter = contentOffset.y - contentHeight / 2.0f;
	CGFloat fullPaletteHeight = self.selectableColors.count * self.privateGeometry.distance;
	
	// If we're off by more than two "pages", re-center so that there more is room for free scrolling.
	BOOL shouldAdjustContentOffset = (ABS (distanceToContentCenter) > fullPaletteHeight * 2.0f);
	if (shouldAdjustContentOffset) {
		
		CGFloat delta = (CGFloat)floor (distanceToContentCenter / fullPaletteHeight) * fullPaletteHeight;
		CGAffineTransform offset = CGAffineTransformMakeTranslation (0, -delta);
		
		self.privateScrollView.contentOffset = CGPointApplyAffineTransform (contentOffset, offset);
	}
}

/// Updates the two color swatch layer positions abd colors to reflect the current content offset.
- (void)JB_updateColorSwatchLayers {
	
	NSUInteger mostVisibleColorIndex = [self JB_mostVisibleColorIndexAtContentOffset:self.privateScrollView.contentOffset];
	CGFloat radius = self.privateGeometry.diameter / 2.0f;
	
	CGPoint selectedLayerOffset = [self JB_contentOffsetForColorIndex:mostVisibleColorIndex nearest:self.privateScrollView.contentOffset];
	CGPoint selectedLayerCenter = CGPointApplyAffineTransform (selectedLayerOffset, CGAffineTransformMakeTranslation (radius, radius));
	UIColor *selectedColor = self.selectableColors[mostVisibleColorIndex];
	
	CGFloat secondaryDistance = (selectedLayerCenter.y - self.privateScrollView.contentOffset.y < radius ? self.privateGeometry.distance : -self.privateGeometry.distance);
	CGPoint secondaryLayerCenter = CGPointApplyAffineTransform (selectedLayerCenter, CGAffineTransformMakeTranslation (0, secondaryDistance));
	NSUInteger secondaryColorIndex = (mostVisibleColorIndex + (secondaryDistance < 0 ? self.selectableColors.count - 1 : 1)) % self.selectableColors.count;
	UIColor *secondaryColor = self.selectableColors[secondaryColorIndex];
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	self.privateSelectedLayer.position = selectedLayerCenter;
	self.privateSelectedLayer.backgroundColor = selectedColor.CGColor;
	
	self.privateSecondaryLayer.position = secondaryLayerCenter;
	self.privateSecondaryLayer.backgroundColor = secondaryColor.CGColor;
	
	[CATransaction commit];
	
	// Store the value of the most visible color index so we know the color the privateSelectedLayer represents.
	[self.privateSelectedLayer setValue:@(mostVisibleColorIndex) forKeyPath:kSelectedColorIndexKeyPath];
}

- (void)JB_selectNextElementInDirection:(UIAccessibilityScrollDirection)direction animated:(BOOL)animated {
	
	if (self.selectableColors.count == 0) {
		return;
	}
	
	NSUInteger selectedColorIndex = self.selectedColorIndex;
	NSInteger delta = (direction == UIAccessibilityScrollDirectionNext ? 1 : -1);
	
	if (selectedColorIndex == NSNotFound) {
		selectedColorIndex = (delta > 0 ? 0 : self.selectableColors.count - 1); // Select first or last
	} else {
		selectedColorIndex = (selectedColorIndex + self.selectableColors.count + delta) % self.selectableColors.count;
	}
	
	[self setSelectedColorIndex:selectedColorIndex animated:animated];
}

/// Convenience method for scrolling to the nearest color given by the index.
- (void)JB_scrollToColorSwatchLayerAtIndex:(NSUInteger)index animated:(BOOL)animated {
	CGPoint nearestContentOffset = [self JB_contentOffsetForColorIndex:(index == NSNotFound ? 0 : index) nearest:self.privateScrollView.contentOffset];
	[self.privateScrollView setContentOffset:nearestContentOffset animated:animated];
}

/// Returns the color index, corresponding to the swatch layer which is the most visible, at the given offset. That is the swatch covering (or closest to) the visible center.
- (NSUInteger)JB_mostVisibleColorIndexAtContentOffset:(CGPoint)offset {
	
	// Note that color index 0 is placed at CGPointZero.
	NSUInteger colorSlotNumber = (NSUInteger)((offset.y + self.privateGeometry.distance / 2.0f) / self.privateGeometry.distance);
	NSUInteger mostVisibleColorIndex = colorSlotNumber % self.selectableColors.count;
	
	return mostVisibleColorIndex;
}

/** Returns the scroll view content offset, nearest the given offset, representing the color at the given index.
 @note Currently only vertical arrangement is supported.
 */
- (CGPoint)JB_contentOffsetForColorIndex:(NSUInteger)colorIndex nearest:(CGPoint)nearestOffset {
	
	CGFloat fullPaletteHeight = self.selectableColors.count * self.privateGeometry.distance;
	NSUInteger fullPaletteCount = (NSUInteger)floor (nearestOffset.y / fullPaletteHeight);
	
	CGPoint colorOffset = nearestOffset;
	colorOffset.y = fullPaletteCount * fullPaletteHeight + colorIndex * self.privateGeometry.distance;
	
	// Check to see if we can get closer to the given nearest offset.
	if (ABS (colorOffset.y - nearestOffset.y) > fullPaletteHeight / 2.0f) {
		colorOffset.y += (colorOffset.y < nearestOffset.y ? fullPaletteHeight : -fullPaletteHeight);
	}
	
	return colorOffset;
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
