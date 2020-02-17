//
//  PngPreviewView.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "PngPreviewView.h"

#import "RGBAFrameCopier.h"
#import "png_decoder.h"
#import "rgba_frame.h"

@interface PngPreviewView()
@property (nonatomic, copy)   NSString*     filePath;
@property (nonatomic, assign) BOOL          readyToRender;
@end

@implementation PngPreviewView
{
    RGBAFrameCopier*                        _frameCopier;
    RGBAFrame*                              _frame;
}

- (instancetype)initWithFrame:(CGRect)frame filePath:(NSString*)filePath {
    if (self = [super initWithFrame:frame]) {
        _filePath = filePath;
        // 确保当前绑定了上下文
        [self bindEAGLContext];
        // 获取图片的展示信息
        _frame = [self getRGBAFrame:_filePath];
        // 初始化渲染器（将图片像素拷贝到OpenGL的纹理上进行展示）
        _frameCopier = [[RGBAFrameCopier alloc] init];
        // 颜色帧准备工作
        if (![_frameCopier prepareRender:_frame->width height:_frame->height]) {
            self.readyToRender = NO;
        }
        self.readyToRender = YES;
    }
    return self;
}

- (void)coreRender {
    if (!self.readyToRender) {
        glFinish();
        return;
    }
    if (_frame) {
        glViewport(0, self.backingHeight - self.backingWidth - 75, self.backingWidth, self.backingWidth);
        [_frameCopier renderFrame:_frame->pixels];
    }
}

- (RGBAFrame*)getRGBAFrame:(NSString*)pngFilePath {
    PngPicDecoder* decoder = new PngPicDecoder();
    char* pngPath = (char*)[pngFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    // 打开png文件
    decoder->openFile(pngPath);
    // 获取图像数据
    RawImageData data = decoder->getRawImageData();
    // 配置 RGBAFrame
    RGBAFrame* frame = new RGBAFrame();
    frame->width = data.width;   // 像素宽度
    frame->height = data.height; // 像素高度
    int expectLength = data.width * data.height * 4; // 像素总长度
    // 实例化像素数组（一个像素占一个字节）
    uint8_t * pixels = new uint8_t[expectLength];
    memset(pixels, 0, sizeof(uint8_t) * expectLength);
    int pixelsLength = MIN(expectLength, data.size);
    memcpy(pixels, (byte*)data.data, pixelsLength);
    frame->pixels = pixels;
    // 释放和关闭操作
    decoder->releaseRawImageData(&data);
    decoder->closeFile();
    delete decoder;
    return frame;
}

- (void)destroy {
    [super destroy];
    dispatch_sync(self.contextQueue, ^{
        if (_frameCopier) {
            [_frameCopier releaseRender];
        }
    });
}

- (void)dealloc {
    _frameCopier = nil;
}

@end
