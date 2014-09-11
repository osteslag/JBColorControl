//
//  JBColorControl.h
//
//  Created by Joachim Bondo on 19/05/2014.
//  Copyright (c) 2014 Cocoa Stuff. All rights reserved.
//

@import UIKit;

/** This control shows and allows the user to pick a color.
 @note Currently only vertical scrolling is supported.
 @note Set specific Accessibility label and values if applicable.
 
 @todo Add UI_APPEARANCE_SELECTOR support (use tintColor for enabled, compute disabled).
 @todo Disable scrolling if less than two selectable colors.
 @todo Properly support no selection (selectedColorIndex == NSNotFound, both enabled/disabled, updating to/from, animated and not).
 */
@interface JBColorControl : UIControl

/** The possible colors that can be chosen.
 @note Speficy nil, or just the selected color, to prevent user selection.
 @note If this is being set while a different color is selected, and the selected color is not in the new array, the first element in the new array is selected.
 */
@property (nonatomic, copy) NSArray *selectableColors;

/** The selected color. KVO compliant convenience property for looking up the selectedIndex in selectableColors.
 @seealso selectedColorIndex, setSelectedColor:animated:.
 */
@property (nonatomic, strong) UIColor *selectedColor;

/** Property for the selected color as an index into the array of selected colors.
 @seealso selectableColors, selectedColor.
 */
@property (nonatomic, assign) NSUInteger selectedColorIndex;

/** Array of localized Accessibility values, mapped 1:1 with elements in selectableColors.
 @seealso selectableColors, localizedAccessibilityNoSelectionValue.
 */
@property (nonatomic, copy) NSArray *localizedAccessibilityValues;

/** Localized string to use as Accessibility Value when there is no selected color.
 @seealso localizedAccessibilityValues, selectableColors.
 */
@property (nonatomic, copy) NSString *localizedAccessibilityNoSelectionValue;

/// Designated value setter, gives the option to set the color animated.
- (void)setSelectedColorIndex:(NSUInteger)selectedColorIndex animated:(BOOL)animated;

/** Sets the color, possibly animated. 
 @note If the given color is not in the selectableColors array, the array will be set to only hold the given color
 @param animated If set to YES, fades or scrolls from the current color to the given color.
 */
- (void)setSelectedColor:(UIColor *)color animated:(BOOL)animated;

@end
