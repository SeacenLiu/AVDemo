//
//  PngPreviewController.m
//  OpenGLRenderer
//
//  Created by bobo on 2019/11/28.
//  Copyright © 2019年 SeacenLiu. All rights reserved.
//

#import "PngPreviewController.h"
#import "./opengl/PreviewView.h"

@interface PngPreviewController ()

@end

@implementation PngPreviewController
{
    PreviewView*            _previewView;
}

+ (instancetype)viewControllerWithContentPath:(NSString *)path contentFrame:(CGRect)frame {
    return [[self alloc] initWithContentPath:path contentFrame:frame];
}

- (instancetype)initWithContentPath:(NSString *)path contentFrame:(CGRect)frame {
    if (self = [super init]) {
        // 初始化 OpenGL 相关代码
        _previewView = [[PreviewView alloc] initWithFrame:frame filePath:path];
        _previewView.contentMode = UIViewContentModeScaleAspectFill;
        self.view.backgroundColor = [UIColor whiteColor];
        [self.view insertSubview:_previewView atIndex:0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 渲染视图
    [_previewView render];
}

- (void) dealloc {
    if(_previewView){
        [_previewView destroy];
        _previewView = nil;
    }
}

@end
