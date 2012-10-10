//
//  Circle.h
//  Bounce
//
//  Created by D. J. Holt on 10/9/12.
//
//

#import <Foundation/Foundation.h>

@interface Circle : NSObject

@property (nonatomic, strong) NSMutableSet *collisions;
@property (nonatomic, assign) CGPoint direction;
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) CGPoint gravity;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, strong) UIColor *color;

+ (Circle *)circleAtPosition:(CGPoint)position;

- (void)draw;
- (void)interactWithCircles:(NSArray *)circles;

- (CGPoint)nextPosition;

@end
