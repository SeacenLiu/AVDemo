//
//  PreviewView.m
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/28.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "PreviewView.h"
#import "RGBAFrameCopier.h"
#import "png_decoder.h"
#import "rgba_frame.h"

@interface PreviewView()
@property (atomic) BOOL readyToRender;
@property (nonatomic, assign) BOOL shouldEnableOpenGL;
@property (nonatomic, strong) NSLock *shouldEnableOpenGLLock;
@end

@implementation PreviewView
{
    dispatch_queue_t                        _contextQueue;
    EAGLContext*                            _context;
    GLuint                                  _displayFramebuffer;
    GLuint                                  _renderbuffer;
    GLint                                   _backingWidth;
    GLint                                   _backingHeight;
    
    BOOL                                    _stopping;
    
    RGBAFrameCopier*                        _frameCopier;
    RGBAFrame*                              _frame;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame filePath:(NSString*)filePath;
{
    self = [super initWithFrame:frame];
    if (self) {
        // 初始化渲染锁
        _shouldEnableOpenGLLock = [NSLock new];
        [_shouldEnableOpenGLLock lock];
        _shouldEnableOpenGL = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
        [_shouldEnableOpenGLLock unlock];
        
        // 监听应用状态
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // 配置layer属性
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        // 使用GCD队列，用于为OpenGL渲染开辟线程
        _contextQueue = dispatch_queue_create("com.changba.video_player.videoRenderQueue", NULL);
        dispatch_sync(_contextQueue, ^{
            // EAGL 与 OpenGL ES 建立连接
            _context = [self buildEAGLContext];
            if (!_context || ![EAGLContext setCurrentContext:_context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            
            // 将 EAGL 与 Layer 连接起来
            if(![self createDisplayFramebuffer]){
                NSLog(@"create Dispaly Framebuffer failed...");
            }
            
            
            _frame = [self getRGBAFrame:filePath];
            _frameCopier = [[RGBAFrameCopier alloc] init];
            if (![_frameCopier prepareRender:_frame->width height:_frame->height]) {
                NSLog(@"RGBAFrameCopier prepareRender failed...");
            }
            self.readyToRender = YES;
        });
        
    }
    return self;
}

- (void)render;
{
    if (_stopping) {
        return;
    }
    dispatch_async(_contextQueue, ^{
        if(_frame) {
            [self.shouldEnableOpenGLLock lock];
            if (!self.readyToRender || !self.shouldEnableOpenGL) {
                glFinish();
                [self.shouldEnableOpenGLLock unlock];
                return;
            }
            [self.shouldEnableOpenGLLock unlock];
            // 绑定当前上下文环境
            [EAGLContext setCurrentContext:_context];
            glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
            
            // *** 绘制部分 ***
            // 规定窗口大小
            glViewport(0, _backingHeight - _backingWidth - 75, _backingWidth, _backingWidth);
            // 帧渲染
            [_frameCopier renderFrame:_frame->pixels];
            // 
            glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
            [_context presentRenderbuffer:GL_RENDERBUFFER];
        }
    });
}

- (RGBAFrame*) getRGBAFrame:(NSString*) pngFilePath;
{
    PngPicDecoder* decoder = new PngPicDecoder();
    char* pngPath = (char*)[pngFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    decoder->openFile(pngPath);
    RawImageData data = decoder->getRawImageData();
    RGBAFrame* frame = new RGBAFrame();
    frame->width = data.width;
    frame->height = data.height;
    int expectLength = data.width * data.height * 4;
    uint8_t * pixels = new uint8_t[expectLength];
    memset(pixels, 0, sizeof(uint8_t) * expectLength);
    int pixelsLength = MIN(expectLength, data.size);
    memcpy(pixels, (byte*) data.data, pixelsLength);
    frame->pixels = pixels;
    decoder->releaseRawImageData(&data);
    decoder->closeFile();
    delete decoder;
    return frame;
}

- (EAGLContext*)buildEAGLContext
{
    return [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
}

- (BOOL)createDisplayFramebuffer;
{
    BOOL ret = TRUE;
    // 创建帧缓冲区
    glGenFramebuffers(1, &_displayFramebuffer);
    // 创建绘制缓冲区
    glGenRenderbuffers(1, &_renderbuffer);
    // 绑定帧缓冲区到渲染管线
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    // 绑定绘制缓冲区到渲染管线
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    // 为绘制缓冲区分配存储区，此处将 CAEAGLLayer 的绘制存储区作为绘制缓冲区的存储区
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
    // 获取绘制缓冲区的像素宽度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    // 获取绘制缓冲区的像素高度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    // 将绘制缓冲区绑定到帧缓冲区
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    // 检查 FrameBuffer 的 status
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
        return FALSE;
    }
    
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
        return FALSE;
    }
    return ret;
}

- (void)destroy;
{
    _stopping = true;
    dispatch_sync(_contextQueue, ^{
        if(_frameCopier) {
            [_frameCopier releaseRender];
        }
        if (_displayFramebuffer) {
            glDeleteFramebuffers(1, &_displayFramebuffer);
            _displayFramebuffer = 0;
        }
        if (_renderbuffer) {
            glDeleteRenderbuffers(1, &_renderbuffer);
            _renderbuffer = 0;
        }
        if ([EAGLContext currentContext] == _context) {
            [EAGLContext setCurrentContext:nil];
        }
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_contextQueue) {
        _contextQueue = nil;
    }
    _frameCopier = nil;
    _context = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = NO;
    [self.shouldEnableOpenGLLock unlock];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self.shouldEnableOpenGLLock lock];
    self.shouldEnableOpenGL = YES;
    [self.shouldEnableOpenGLLock unlock];
}

@end
