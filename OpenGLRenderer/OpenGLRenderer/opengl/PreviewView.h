//
//  PreviewView.h
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/28.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PreviewView : UIView

- (instancetype)initWithFrame:(CGRect)frame filePath:(NSString*)filePath;

- (void)render;

- (void)destroy;

@end
