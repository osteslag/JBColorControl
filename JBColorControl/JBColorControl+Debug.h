//
//  JBColorControl+Debug.h
//  JBColorControl
//
//  Created by Joachim Bondo on 30/07/2014.
//  Copyright (c) 2014 Joachim Bondo. All rights reserved.
//

#import "JBColorControl.h"

/// This category adds functionality to make debugging easier.
@interface JBColorControl (Debug)

@property (nonatomic, assign, getter=isDebugAugmented) BOOL debugAugmented;

@end
