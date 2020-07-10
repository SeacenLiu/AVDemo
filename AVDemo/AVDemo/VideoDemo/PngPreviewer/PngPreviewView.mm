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
        // 记录文件路径（图片获取方式）
        _filePath = filePath;
        // 确保当前绑定了 OpenGL 上下文
        [self bindEAGLContext];
        // 通过 libpng 获取图片的 RGB 展示信息
        _frame = [self getRGBAFrame:_filePath];
        // 初始化渲染器（将图片像素拷贝到OpenGL的纹理上进行展示）
        _frameCopier = [[RGBAFrameCopier alloc] init];
        // 像素渲染器根据画布大小进行准备工作
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
        // 展示位置
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
    // 设置 frame 的描述属性
    frame->width = data.width;   // 像素宽度
    frame->height = data.height; // 像素高度
    int expectLength = data.width * data.height * 4; // 像素总数量
    // 实例化像素数组（一个像素占一个字节）
    uint8_t * pixels = new uint8_t[expectLength];
    memset(pixels, 0, sizeof(uint8_t) * expectLength);
    // 防止溢出
    int pixelsLength = MIN(expectLength, data.size);
    // 像素数组赋值（byte == unsigned char）
    memcpy(pixels, (byte*)data.data, pixelsLength);
    // 像素数组赋值
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
