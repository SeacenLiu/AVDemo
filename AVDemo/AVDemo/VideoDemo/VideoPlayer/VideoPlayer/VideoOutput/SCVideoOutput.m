//
//  SCVideoOutput.m
//  VideoPlayer
//
//  Created by bobo on 2019/12/1.
//  Copyright © 2019年 cppteam. All rights reserved.
//

#import "SCVideoOutput.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "YUVFrameCopier.h"
#import "YUVFrameFastCopier.h"
#import "ContrastEnhancerFilter.h"
#import "DirectPassRenderer.h"
#import "VideoDecoder.h"

/**
 * 本类的职责:
 *  1:作为一个UIView的子类, 必须提供layer的绘制, 我们这里是靠RenderBuffer和我们的CAEAGLLayer进行绑定来绘制的
 *  2:需要构建OpenGL的环境, EAGLContext与运行Thread
 *  3:调用第三方的Filter与Renderer去把YUV420P的数据处理以及渲染到RenderBuffer上
 *  4:由于这里面涉及到OpenGL的操作, 要增加NotificationCenter的监听, 在applicationWillResignActive 停止绘制
 *
 */

@interface SCVideoOutput()

@property (atomic) BOOL readyToRender;
@property (nonatomic, assign) BOOL shouldEnableOpenGL;
@property (nonatomic, strong) NSLock *shouldEnableOpenGLLock;
@property (nonatomic, strong) NSOperationQueue *renderOperationQueue;

@end


@implementation SCVideoOutput
{
    EAGLContext*                            _context;
    GLuint                                  _displayFramebuffer;
    GLuint                                  _renderbuffer;
    GLint                                   _backingWidth;
    GLint                                   _backingHeight;
    
    BOOL                                    _stopping;
    
    // YUV 帧渲染
    YUVFrameCopier*                         _videoFrameCopier;
    
    // 基础滤镜效果
    BaseEffectFilter*                       _filter;
    
    // 直接通过渲染器？
    DirectPassRenderer*                     _directPassRenderer;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame textureWidth:(NSInteger)textureWidth textureHeight:(NSInteger)textureHeight usingHWCodec: (BOOL) usingHWCodec {
    return [self initWithFrame:frame textureWidth:textureWidth textureHeight:textureHeight usingHWCodec:usingHWCodec shareGroup:nil];
}

#pragma mark - core init
- (instancetype)initWithFrame:(CGRect)frame
                 textureWidth:(NSInteger)textureWidth
                textureHeight:(NSInteger)textureHeight
                 usingHWCodec:(BOOL)usingHWCodec
                   shareGroup:(EAGLSharegroup *)shareGroup {
    if (self = [super initWithFrame:frame]) {
        // OpenGL 渲染锁
        _shouldEnableOpenGLLock = [NSLock new];
        [_shouldEnableOpenGLLock lock];
        _shouldEnableOpenGL = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
        [_shouldEnableOpenGLLock unlock];
        
        // 通知监听
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // 配置 CAEAGLLayer 属性
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        // 渲染操作队列
        _renderOperationQueue = [[NSOperationQueue alloc] init];
        _renderOperationQueue.maxConcurrentOperationCount = 1;
        _renderOperationQueue.name = @"com.seacenliu.video_player.videoRenderQueue";
        
        // 渲染操作核心处理
        __weak SCVideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{
            if (!weakSelf) {
                return;
            }
            
            __strong SCVideoOutput *strongSelf = weakSelf;
            // 初始化 EAGLContext
            if (shareGroup) {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
            } else {
                strongSelf->_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            }
            
            // 设置当前上下文
            if (!strongSelf->_context || ![EAGLContext setCurrentContext:strongSelf->_context]) {
                NSLog(@"Setup EAGLContext Failed...");
            }
            
            // 创建帧缓冲和渲染缓冲
            if(![strongSelf createDisplayFramebuffer]){
                NSLog(@"create Dispaly Framebuffer failed...");
            }
            
            // 创建当前帧渲染器
            [strongSelf createCopierInstance:usingHWCodec];
            // 渲染器准备
            if (![strongSelf->_videoFrameCopier prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_videoFrameFastCopier prepareRender failed...");
            }
            
            // 创建滤镜
            strongSelf->_filter = [self createImageProcessFilterInstance];
            // 渲染器准备
            if (![strongSelf->_filter prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_contrastEnhancerFilter prepareRender failed...");
            }
            // _videoFrameCopier ==> _contrastEnhancerFilter
            [strongSelf->_filter setInputTexture:[strongSelf->_videoFrameCopier outputTextureID]];
            
            // 创建直通渲染器
            strongSelf->_directPassRenderer = [[DirectPassRenderer alloc] init];
            // 渲染器准备
            if (![strongSelf->_directPassRenderer prepareRender:textureWidth height:textureHeight]) {
                NSLog(@"_directPassRenderer prepareRender failed...");
            }
            // _contrastEnhancerFilter ==> _directPassRenderer
            [strongSelf->_directPassRenderer setInputTexture:[strongSelf->_filter outputTextureID]];
            
            strongSelf.readyToRender = YES;
        }];
    }
    return self;
}

- (BaseEffectFilter*)createImageProcessFilterInstance {
    return [[ContrastEnhancerFilter alloc] init];
}

- (BaseEffectFilter*)getImageProcessFilterInstance {
    return _filter;
}

- (void)createCopierInstance:(BOOL)usingHWCodec {
    if(usingHWCodec){
        // 硬编码帧渲染
        _videoFrameCopier = [[YUVFrameFastCopier alloc] init];
    } else{
        // 软编码帧渲染
        _videoFrameCopier = [[YUVFrameCopier alloc] init];
    }
}

// 渲染的帧数量
static int count = 0;
//static int totalDroppedFrames = 0;

//当前operationQueue里允许最多的帧数，理论上好的机型上不会有超过1帧的情况，差一些的机型（比如iPod touch），渲染的比较慢，
//队列里可能会有多帧的情况，这种情况下，如果有超过三帧，就把除了最近3帧以前的帧移除掉（对应的operation cancel掉）
static const NSInteger kMaxOperationQueueCount = 3;

- (void)presentVideoFrame:(VideoFrame*)frame {
    if (_stopping) {
        NSLog(@"Prevent A InValid Renderer >>>>>>>>>>>>>>>>>");
        return;
    }
    
    @synchronized (self.renderOperationQueue) {
        NSInteger operationCount = _renderOperationQueue.operationCount;
        // 超过缓冲限制丢帧处理
        if (operationCount > kMaxOperationQueueCount) {
            [_renderOperationQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull operation, NSUInteger idx, BOOL * _Nonnull stop) {
                if (idx < operationCount - kMaxOperationQueueCount) {
                    [operation cancel];
                } else {
                    //totalDroppedFrames += (idx - 1);
                    //NSLog(@"===========================❌ Dropped frames: %@, total: %@", @(idx - 1), @(totalDroppedFrames));
                    *stop = YES;
                }
            }];
        }
        
        // 渲染任务
        __weak SCVideoOutput *weakSelf = self;
        [_renderOperationQueue addOperationWithBlock:^{
            if (!weakSelf) {
                return;
            }

            __strong SCVideoOutput *strongSelf = weakSelf;

            [strongSelf.shouldEnableOpenGLLock lock];
            if (!strongSelf.readyToRender || !strongSelf.shouldEnableOpenGL) {
                // 未准备或禁用 OpenGL 需要调用 glFinish() 停止渲染
                glFinish();
                [strongSelf.shouldEnableOpenGLLock unlock];
                return;
            }
            [strongSelf.shouldEnableOpenGLLock unlock];
            
            count++;
            int frameWidth = (int)[frame width];
            int frameHeight = (int)[frame height];
            
            // 确保配置了当前 OpenGL 上下文
            [EAGLContext setCurrentContext:strongSelf->_context];
            // 使用帧数据进行渲染
            [strongSelf->_videoFrameCopier renderWithTexId:frame];
            // 按照宽高位置进行渲染
            [strongSelf->_filter renderWithWidth:frameWidth height:frameHeight position:frame.position];

            // 绑定当前帧缓冲
            glBindFramebuffer(GL_FRAMEBUFFER, strongSelf->_displayFramebuffer);
            // 按照宽高位置进行渲染
            [strongSelf->_directPassRenderer renderWithWidth:strongSelf->_backingWidth height:strongSelf->_backingHeight position:frame.position];
            // 绑定当前渲染缓冲
            glBindRenderbuffer(GL_RENDERBUFFER, strongSelf->_renderbuffer);
            
            // 展示当前渲染帧
            [strongSelf->_context presentRenderbuffer:GL_RENDERBUFFER];
        }];
    }
    
}

- (BOOL)createDisplayFramebuffer {
    BOOL ret = TRUE;
    // 帧缓冲与渲染缓冲创建与绑定
    glGenFramebuffers(1, &_displayFramebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _displayFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    // 为绑定的OpenGL ES 渲染缓冲对象附加一个 EAGLDrawable 作为存储
    // 这个不能会主线程
//    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
//    });
    
    // 获取渲染缓冲的宽度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    // 获取渲染缓冲的高度
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    // 将渲染缓冲挂载到当前帧缓冲区上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    // 检查当前帧缓冲情况
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
        return FALSE;
    }
    // 捕获当前错误
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
        return FALSE;
    }
    
    return ret;
}

- (void)destroy {
    _stopping = true;
    
    __weak SCVideoOutput *weakSelf = self;
    [self.renderOperationQueue addOperationWithBlock:^{
        if (!weakSelf) {
            return;
        }
        __strong SCVideoOutput *strongSelf = weakSelf;
        if(strongSelf->_videoFrameCopier) {
            [strongSelf->_videoFrameCopier releaseRender];
        }
        if(strongSelf->_filter) {
            [strongSelf->_filter releaseRender];
        }
        if(strongSelf->_directPassRenderer) {
            [strongSelf->_directPassRenderer releaseRender];
        }
        if (strongSelf->_displayFramebuffer) {
            glDeleteFramebuffers(1, &strongSelf->_displayFramebuffer);
            strongSelf->_displayFramebuffer = 0;
        }
        if (strongSelf->_renderbuffer) {
            glDeleteRenderbuffers(1, &strongSelf->_renderbuffer);
            strongSelf->_renderbuffer = 0;
        }
        if ([EAGLContext currentContext] == strongSelf->_context) {
            [EAGLContext setCurrentContext:nil];
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_renderOperationQueue) {
        [_renderOperationQueue cancelAllOperations];
        _renderOperationQueue = nil;
    }
    
    _videoFrameCopier = nil;
    _filter = nil;
    _directPassRenderer = nil;
    
    _context = nil;
    NSLog(@"Render Frame Count is %d", count);
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
