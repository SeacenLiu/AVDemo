//
//  PngPreviewController.h
//  OpenGLRenderer
//
//  Created by bobo on 2019/11/28.
//  Copyright © 2019年 SeacenLiu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PngPreviewController : UIViewController

- (instancetype)initWithContentPath:(NSString *)path contentFrame:(CGRect)frame;
+ (instancetype)viewControllerWithContentPath:(NSString*)path contentFrame:(CGRect)frame;

@end
