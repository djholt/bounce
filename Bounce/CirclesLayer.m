//
//  CirclesLayer.m
//  Bounce
//
//  Created by D. J. Holt on 10/9/12.
//
//

#import "CirclesLayer.h"
#import "Circle.h"

@implementation CirclesLayer
{
    NSMutableArray *_circles;
}

+ (CCScene *)scene
{
	CCScene *scene = [CCScene node];
	CirclesLayer *layer = [CirclesLayer node];
	[scene addChild:layer];
	return scene;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.isTouchEnabled = YES;
        self.isAccelerometerEnabled = YES;
        _circles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_circles release];
    [super dealloc];
}

- (void)draw
{
    [_circles enumerateObjectsUsingBlock:^(Circle *circle, NSUInteger idx, BOOL *stop) {
        [circle interactWithCircles:_circles];
    }];

    [_circles enumerateObjectsUsingBlock:^(Circle *circle, NSUInteger idx, BOOL *stop) {
        [circle draw];
    }];
}

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (event.allTouches.count > 2)
    {
        [_circles removeAllObjects];
    }
    else
    {
        UITouch *touch = [touches anyObject];
        CGPoint position = [touch locationInView:touch.view];
        position = [[CCDirector sharedDirector] convertToGL:position];
        [_circles addObject:[Circle circleAtPosition:position]];
    }
}

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    CGPoint gravity = ccpRotateByAngle(CGPointMake(acceleration.x, acceleration.y), CGPointZero, M_PI_2);
    [_circles enumerateObjectsUsingBlock:^(Circle *circle, NSUInteger idx, BOOL *stop) {
        circle.gravity = gravity;
    }];
}

@end
