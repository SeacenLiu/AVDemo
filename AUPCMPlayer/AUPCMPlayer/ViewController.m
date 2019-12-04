//
//  ViewController.m
//  AUPCMPlayer
//
//  Created by bobo on 2019/12/3.
//  Copyright © 2019年 seacenliu. All rights reserved.
//

#import "ViewController.h"
#import "SCPlayer.h"

@interface ViewController ()
@property (nonatomic, strong) SCPlayer *player;
@end

@implementation ViewController

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_player play];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"pcm"];
    _player = [[SCPlayer alloc] initWithFileURL:url];
}


@end
