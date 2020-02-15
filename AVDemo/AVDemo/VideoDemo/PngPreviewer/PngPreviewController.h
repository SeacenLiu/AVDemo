//
//  PngPreviewController.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PngPreviewController : UIViewController

- (instancetype)initWithContentPath:(NSString *)path contentFrame:(CGRect)frame;
+ (instancetype)viewControllerWithContentPath:(NSString*)path contentFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
