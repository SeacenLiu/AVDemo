//
//  PngPreviewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "PngPreviewController.h"
#import "PngPreviewView.h"

@interface PngPreviewController ()

@end

@implementation PngPreviewController
{
    PngPreviewView*            _previewView;
}

+ (instancetype)viewControllerWithContentPath:(NSString *)path contentFrame:(CGRect)frame {
    return [[self alloc] initWithContentPath:path contentFrame:frame];
}

- (instancetype)initWithContentPath:(NSString *)path contentFrame:(CGRect)frame {
    if (self = [super init]) {
        // 初始化 OpenGL 相关代码
        _previewView = [[PngPreviewView alloc] initWithFrame:frame filePath:path];
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
        // 销毁视图
        [_previewView destroy];
        _previewView = nil;
    }
}

@end
