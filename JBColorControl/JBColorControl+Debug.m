//
//  JBColorControl+Debug.m
//  JBColorControl
//
//  Created by Joachim Bondo on 30/07/2014.
//  Copyright (c) 2014 Joachim Bondo. All rights reserved.
//

#import "JBColorControl+Debug.h"
#import <objc/runtime.h>

static CGFloat const kCanvasLeftMargin = 48; // Extra width for the readout markers and labels
static CGFloat const kCanvasHeightFactor = 5; // Five times the scroll view content height

static CGFloat const kReadoutLabelDelta = 50; // Readout per 50 points
static CGFloat const kReadoutMarkerDelta = 10; // Minor marker per 10 points
static NSInteger const kReadoutMinorMarkersPerMajor = 5; // Major markers per 50 points
static CGFloat const kReadoutMarkerWidthMajor = 6;
static CGFloat const kReadoutMarkerWidthMinor = 3;
static CGFloat const kReadoutTextInset = 9; // From left edge
static CGFloat const kReadoutFontSize = 11;
static CGSize const kReadoutLabelSize = {kCanvasLeftMargin - kReadoutTextInset, 13};
static UIEdgeInsets const kReadoutOffsetInsets = {2, 0, 0, 3};

static char const * const kAssociatedCanvasViewKey = "debug_canvasView";
static NSString * const kObservedScrollViewUpdateKeyPath = @"bounds";

@implementation JBColorControl (Debug)

- (BOOL)isDebugAugmented {
	return !self.clipsToBounds; // Does not clip to bounds when debugging
}

- (void)setDebugAugmented:(BOOL)debugAugmented {
	if (self.debugAugmented != debugAugmented) {
		[self debug_setUpForDebugging:debugAugmented];
	}
}

#pragma mark Private Ivar Getters

/// Root subview, hosting layers for readout labels and markers.
- (UIView *)debug_associatedCanvasView {
	return objc_getAssociatedObject (self, kAssociatedCanvasViewKey);
}

- (void)debug_setAssociatedCanvasView:(UIView *)canvasView {
	objc_setAssociatedObject (self, kAssociatedCanvasViewKey, canvasView, OBJC_ASSOCIATION_ASSIGN); // Retained by self
}

- (UIScrollView *)debug_privateScrollView {
	UIScrollView *privateScrollView = [self valueForKeyPath:@"privateScrollView"];
	BOOL shouldHavePrivateScrollView = self.enabled;
	NSAssert (!shouldHavePrivateScrollView || [privateScrollView isDescendantOfView:self], @"Looks like we don't have the correct view.");
	return privateScrollView;
}

#pragma mark - NSKeyValueObserving Protocol

/// @warning As long as the public class does not implement this, we're good.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	
	if ([keyPath isEqualToString:kObservedScrollViewUpdateKeyPath]) {
		[self debug_updateReadoutLayersForPrivateScrollView:object];
	}
	
}

#pragma mark - Debug-private Methods

/** Set up debug view hierarchy.
 @discussion A canvas subview is added to the control, self. With the canvas view layer as root, two full view frame layers are added: a layer containing text layers for the labels, and a layer containing markers.
 */
- (void)debug_setUpForDebugging:(BOOL)isDebugging {
	
	UIScrollView *privateScrollView = [self debug_privateScrollView];
	UIView *canvasView = [self debug_associatedCanvasView];
	objc_getAssociatedObject (self, kAssociatedCanvasViewKey);
	
	self.clipsToBounds = privateScrollView.clipsToBounds = !isDebugging;
	
	if (isDebugging) {
		
		NSAssert (!canvasView, @"About to set private canvas view while we already have one.");
		
		// Set up canvas layer for scroll view readouts.
		
		// Vertically center tall canvas, add margin for the readouts.
		CGRect canvasFrame = self.bounds;
		canvasFrame.size.width += kCanvasLeftMargin + kReadoutOffsetInsets.right;
		canvasFrame.size.height *= kCanvasHeightFactor;
		canvasFrame.origin.x -= kCanvasLeftMargin;
		canvasFrame.origin.y = roundf (-canvasFrame.size.height / 2.5f);
		
		UIView *canvasView = [[UIView alloc] initWithFrame:canvasFrame];
		canvasView.backgroundColor = [self.tintColor colorWithAlphaComponent:0.2f];
		canvasView.clipsToBounds = YES;
		
		[privateScrollView addObserver:self forKeyPath:kObservedScrollViewUpdateKeyPath options:0x00 context:NULL];
		
		[self insertSubview:canvasView atIndex:0];
		
		[self debug_setAssociatedCanvasView:canvasView];
		[self debug_addReadoutLayers]; // Assumes associated canvas layer
		[self debug_updateReadoutLayersForPrivateScrollView:privateScrollView];
	}
	
	else { // Clean up
		[privateScrollView removeObserver:self forKeyPath:kObservedScrollViewUpdateKeyPath];
		[canvasView removeFromSuperview];
		[self debug_setAssociatedCanvasView:nil];
	}
}

#pragma mark Readouts

/** Add label and marker layers.
 @note Layers will be positioned in -debug_updateReadoutLayersForPrivateScrollView:.
 */
- (void)debug_addReadoutLayers {
	
	CALayer *canvasLayer = [self debug_associatedCanvasView].layer;
	CGColorRef readoutColor = self.tintColor.CGColor;
	
	NSUInteger markerCount = ceilf (canvasLayer.bounds.size.height / kReadoutMarkerDelta) + 1;
	
	CALayer *markerContainerLayer = [CALayer layer];
	markerContainerLayer.frame = canvasLayer.bounds;
	[canvasLayer addSublayer:markerContainerLayer];
	
	for (NSUInteger i = 0; i < markerCount; i++) {
		CALayer *markerLayer = [CALayer layer];
		markerLayer.backgroundColor = readoutColor;
		[markerContainerLayer addSublayer:markerLayer];
	}
	
	NSUInteger labelCount = ceilf (canvasLayer.bounds.size.height / kReadoutLabelDelta) + 2; // An extra label for the content offset readout
	CFTypeRef labelFont = (__bridge CFTypeRef)[UIFont systemFontOfSize:kReadoutFontSize];
	CGRect labelFrame = CGRectMake (kReadoutTextInset, 0, kReadoutLabelSize.width, kReadoutLabelSize.height);
	
	CALayer *labelContainerLayer = [CALayer layer];
	labelContainerLayer.frame = canvasLayer.bounds;
	[canvasLayer addSublayer:labelContainerLayer];
	
	for (NSUInteger i = 0; i < labelCount; i++) {
		CATextLayer *labelLayer = [CATextLayer layer];
		labelLayer.font = labelFont;
		labelLayer.fontSize = kReadoutFontSize;
		labelLayer.foregroundColor = readoutColor;
		labelLayer.contentsScale = [[UIScreen mainScreen] scale];
		labelLayer.anchorPoint = CGPointMake (0, 0.5f);
		labelLayer.frame = labelFrame;
		[labelContainerLayer addSublayer:labelLayer];
	}
}

/// Position readout marker and label layers according to current scroll view offset.
- (void)debug_updateReadoutLayersForPrivateScrollView:(UIScrollView *)scrollView {
	
	UIView *canvasView = [self debug_associatedCanvasView];
	CALayer *markerContainerLayer = canvasView.layer.sublayers[0];
	CALayer *labelContainerLayer = canvasView.layer.sublayers[1];
	
	// Don't animate the transition.
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	// Compute the scroll view coordinate corresponding to the canvas upper edge.
	CGFloat canvasTopEdgeInScrollViewCoordinates = [scrollView convertPoint:CGPointZero fromView:canvasView].y;
	
	[self debug_updateFixedOffsetLabelLayerWithOffset:scrollView.contentOffset.y inLabelContainerLayer:labelContainerLayer];
	[self debug_updateLabelLayersForTopEdge:canvasTopEdgeInScrollViewCoordinates inLabelContainerLayer:labelContainerLayer];
	[self debug_updateMarkerLayersForTopEdge:canvasTopEdgeInScrollViewCoordinates inMarkerContainerLayer:markerContainerLayer];
	
	[CATransaction commit];
}

/** Places the fixed content offset readout label, right-aligned at the top.
 @param offset The current content y offset of our private scroll view.
 */
- (void)debug_updateFixedOffsetLabelLayerWithOffset:(CGFloat)offset inLabelContainerLayer:(CALayer *)labelContainerLayer {
	
	CATextLayer *fixedOffsetLabel = labelContainerLayer.sublayers[0];
	
	NSString *offsetString = [NSString stringWithFormat:@"%0.0f", offset];
	CGFloat offsetLabelWidth = [offsetString sizeWithAttributes:@{NSFontAttributeName:(UIFont *)fixedOffsetLabel.font}].width;
	
	fixedOffsetLabel.string = offsetString;
	fixedOffsetLabel.frame = CGRectMake (labelContainerLayer.bounds.size.width - offsetLabelWidth - kReadoutOffsetInsets.right, kReadoutOffsetInsets.top, offsetLabelWidth, kReadoutLabelSize.height);
}

/** Updates the label layers to reflect the given top edge value.
 @param topEdge The scroll content y value corresponding to the canvas view's top edge.
 @param labelContainerLayer The layer containing all label layers.
 */
- (void)debug_updateLabelLayersForTopEdge:(CGFloat)topEdge inLabelContainerLayer:(CALayer *)labelContainerLayer {
	
	// We will be reusing the existing text layers (the first layer is reserved for the fixed offset readout).
	NSArray *labelLayers = [labelContainerLayer.sublayers subarrayWithRange:NSMakeRange (1, labelContainerLayer.sublayers.count - 1)];
	
	// Compute origin.y for the top-most label. If it is larger than zero, we will place a "sticky" label above.
	CGFloat y = -fmodf (topEdge, kReadoutLabelDelta);
	
	for (CATextLayer *labelLayer in labelLayers) {
		labelLayer.string = [NSString stringWithFormat:@"%0.0f", y + topEdge];
		labelLayer.position = CGPointMake (labelLayer.position.x, y);
		y += kReadoutLabelDelta;
	}
}

/** Updates the marker layers to reflect the given top edge value.
 @param topEdge The scroll content y value corresponding to the canvas view's top edge.
 @param labelContainerLayer The layer containing all label layers.
 */
- (void)debug_updateMarkerLayersForTopEdge:(CGFloat)topEdge inMarkerContainerLayer:(CALayer *)markerContainerLayer {
	
	// Compute y coordinate for first marker.
	CGFloat y = -fmodf (topEdge, kReadoutMarkerDelta);
	NSInteger markerValue = (NSInteger)(topEdge + y);
	
	CGRect markerFrame = CGRectZero;
	markerFrame.size.height = 1.0f / [[UIScreen mainScreen] scale];
	markerFrame.origin.y = y + markerFrame.size.height;
	
	NSInteger majorMarkerDelta = kReadoutMinorMarkersPerMajor * (NSInteger)kReadoutMarkerDelta;
	
	for (CALayer *markerLayer in markerContainerLayer.sublayers) {
		
		BOOL isMajor = markerValue % majorMarkerDelta == 0;
		
		markerFrame.size.width = (isMajor ? kReadoutMarkerWidthMajor : kReadoutMarkerWidthMinor);
		markerFrame.origin.y = y;
		markerLayer.frame = markerFrame;
		
		y += kReadoutMarkerDelta;
		markerValue += (NSUInteger)kReadoutMarkerDelta;
	}
}

@end
