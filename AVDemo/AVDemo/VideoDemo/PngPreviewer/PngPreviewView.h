//
//  PngPreviewView.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PngPreviewView : UIView

- (instancetype)initWithFrame:(CGRect)frame filePath:(NSString*)filePath;

- (void)render;

- (void)destroy;

@end

NS_ASSUME_NONNULL_END
