//
//  FaceLib.h
//  FaceLib
//
//  Created by Koji Suzuki on 2017/04/03.
//  Copyright © 2017 Koji Suzuki. All rights reserved.
//

#ifndef FaceLib_h
#define FaceLib_h

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface FaceLib : NSObject

- (NSArray<NSArray<NSArray<NSValue *> *> *> *)getFeatures:(CMSampleBufferRef)sampleBuffer bounds:(NSArray<NSValue *> *)rects;
- (void)dispPartsFlag:(BOOL)flg;
- (void)dispAnglesFlag:(BOOL)flg;

@end

#endif /* FaceLib_h */
