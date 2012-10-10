//
//  Circle.m
//  Bounce
//
//  Created by D. J. Holt on 10/9/12.
//
//

#import "Circle.h"
#import "cocos2d.h"

#define kAirFriction 0.999
#define kCollisionFriction 0.8
#define kGravity 0.5
#define kOverdrawWidth 1.0
#define kTrianglesPerSector 3

typedef struct _LineVertex {
    CGPoint position;
    float z;
    ccColor4F color;
} LineVertex;

@implementation Circle
{
    CCGLProgram *_shaderProgram;
}

+ (Circle *)circleAtPosition:(CGPoint)position
{
    Circle *circle = [[[self class] alloc] init];
    circle.position = position;
    return [circle autorelease];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.collisions = [NSMutableSet set];
        self.direction = CGPointZero;
        self.position = CGPointZero;
        self.gravity = CGPointZero;
        self.radius = arc4random_uniform(75) + 25;
        self.color = [UIColor colorWithRed:arc4random_uniform(255) / 255.0
                                     green:arc4random_uniform(255) / 255.0
                                      blue:arc4random_uniform(255) / 255.0
                                     alpha:1];
    }
    return self;
}

- (void)dealloc
{
    [_collisions release];
    [_color release];
    [super dealloc];
}

#define ADD_TRIANGLE(A, colorA, B, colorB, C, colorC, Z) triangleVertices[index].position = A, triangleVertices[index].color = colorA, triangleVertices[index++].z = Z, triangleVertices[index].position = B, triangleVertices[index].color = colorB, triangleVertices[index++].z = Z, triangleVertices[index].position = C, triangleVertices[index].color = colorC, triangleVertices[index++].z = Z

- (void)draw
{
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    [self.color getRed:&red green:&green blue:&blue alpha:&alpha];

    ccColor4F drawColor = {red, green, blue, alpha};
    ccColor4F fadeColor = drawColor;
    fadeColor.a = 0;

    NSUInteger numberOfSubsectors = ceil(self.radius);
    NSUInteger numberOfTriangles = numberOfSubsectors * kTrianglesPerSector;
    LineVertex *triangleVertices = calloc(sizeof(LineVertex), numberOfTriangles * 3);

    CGFloat subsectorArcAngle = 2 * M_PI / numberOfSubsectors;

    NSUInteger index = 0;
    CGFloat currentAngle = 0;
    CGPoint dir0 = ccp(cosf(currentAngle), sinf(currentAngle));
    CGPoint p0 = ccpAdd(self.position, ccpMult(dir0, self.radius));
    for (NSUInteger i = 0; i < numberOfSubsectors; i++)
    {
        currentAngle += subsectorArcAngle;

        CGPoint dir1 = ccp(cosf(currentAngle), sinf(currentAngle));
        CGPoint p1   = ccpAdd(self.position, ccpMult(dir1, self.radius));
        CGPoint p0b  = ccpAdd(p0, ccpMult(dir0, kOverdrawWidth));
        CGPoint p1b  = ccpAdd(p1, ccpMult(dir1, kOverdrawWidth));

        ADD_TRIANGLE(self.position, drawColor, p0, drawColor, p1,  drawColor, 1.0f);
        ADD_TRIANGLE(p0b,           fadeColor, p0, drawColor, p1b, fadeColor, 2.0f);
        ADD_TRIANGLE(p0,            drawColor, p1, drawColor, p1b, fadeColor, 2.0f);

        dir0 = dir1;
        p0 = p1;
    }

    if (index > 0)
    {
        [self drawTrianglesWithVertices:triangleVertices count:index];
        CC_INCREMENT_GL_DRAWS(numberOfTriangles);
    }

    free(triangleVertices);
}

- (void)drawTrianglesWithVertices:(LineVertex *)vertices count:(NSUInteger)count
{
    if (_shaderProgram == nil)
    {
        _shaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionColor];
    }

    [_shaderProgram use];
    [_shaderProgram setUniformForModelViewProjectionMatrix];

    ccGLEnableVertexAttribs(kCCVertexAttribFlag_Position | kCCVertexAttribFlag_Color);

    glVertexAttribPointer(kCCVertexAttrib_Position, 3, GL_FLOAT, GL_FALSE, sizeof(LineVertex), &vertices[0].position);
    glVertexAttribPointer(kCCVertexAttrib_Color,    4, GL_FLOAT, GL_FALSE, sizeof(LineVertex), &vertices[0].color);

    ccGLBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glDrawArrays(GL_TRIANGLES, 0, (GLsizei)count);
}

- (void)interactWithCircles:(NSArray *)circles
{
    CGSize winSize = [[CCDirector sharedDirector] winSize];

    // Fall to the ground
    self.direction = ccpAdd(self.direction, ccpMult(self.gravity, kGravity));

    // I'm a leaf on the wind
    self.direction = ccpMult(self.direction, kAirFriction);

    // Run into walls
    CGPoint nextPosition = [self nextPosition];
    CGPoint newDirection = self.direction;
    if (nextPosition.x - self.radius <= 0 || nextPosition.x + self.radius >= winSize.width)
    {
        newDirection.x *= -kCollisionFriction;
    }
    if (nextPosition.y - self.radius <= 0 || nextPosition.y + self.radius >= winSize.height)
    {
        newDirection.y *= -kCollisionFriction;
    }
    self.direction = newDirection;

    // Smash into neighbors
    for (NSUInteger i = [circles indexOfObject:self] + 1; i < circles.count; i++)
    {
        [self collideWithCircle:circles[i]];
    }

    self.position = [self nextPosition];
}

- (void)collideWithCircle:(Circle *)otherCircle
{
    if (ccpDistance(self.position, otherCircle.position) < self.radius + otherCircle.radius)
    {
        if ([self.collisions member:otherCircle])
        {
            return;
        }

        [self.collisions addObject:otherCircle];
    }
    else
    {
        [self.collisions removeObject:otherCircle];
        return;
    }

    CGPoint en;     // Center of Mass coordinate system, normal component
    CGPoint et;     // Center of Mass coordinate system, tangential component
    CGPoint u[2];   // initial velocities of two particles
    CGPoint um[2];  // initial velocities in Center of Mass coordinates
    CGFloat umt[2]; // initial velocities in Center of Mass coordinates, tangent component
    CGFloat umn[2]; // initial velocities in Center of Mass coordinates, normal component
    CGPoint v[2];   // final velocities of two particles
    CGFloat m[2];   // mass of two particles
    CGFloat M;      // mass of two particles together
    CGPoint V;      // velocity of two particles together

    CGPoint diff = ccpNormalize(ccpSub([self nextPosition], [otherCircle nextPosition]));

    en.x = diff.x;
    en.y = diff.y;
    et.x = diff.y;
    et.y = -diff.x;

    u[0] = self.direction;
    m[0] = self.radius * self.radius;
    u[1] = otherCircle.direction;
    m[1] = otherCircle.radius * otherCircle.radius;

    M = m[0] + m[1];
    V = ccpMult(ccpAdd(ccpMult(u[0], m[0]), ccpMult(u[1], m[1])), 1 / M);

    um[0] = ccpMult(ccpSub(u[0], u[1]), m[1] / M);
    um[1] = ccpMult(ccpSub(u[1], u[0]), m[0] / M);

    umt[0] = ccpDot(um[0], et);
    umn[0] = ccpDot(um[0], en);
    umt[1] = ccpDot(um[1], et);
    umn[1] = ccpDot(um[1], en);

    v[0] = ccpAdd(ccpSub(ccpMult(et, umt[0]), ccpMult(en, umn[0])), V);
    v[1] = ccpAdd(ccpSub(ccpMult(et, umt[1]), ccpMult(en, umn[1])), V);

    self.direction        = ccpMult(v[0], kCollisionFriction);
    otherCircle.direction = ccpMult(v[1], kCollisionFriction);
}

- (CGPoint)nextPosition
{
    return ccpAdd(self.position, self.direction);
}

@end
