//
//  Person+Category.m
//  weakPointer
//
//  Created by LL on 2023/12/27.
//

#import "Person+Category.h"

#import <objc/runtime.h>

@implementation Person (Category)

- (void)setWeakObj:(NSObject *)val {
    objc_setAssociatedObject(self, @selector(weakObj), val, OBJC_ASSOCIATION_ASSIGN);
}

- (TestObject *)weakObj {
    return objc_getAssociatedObject(self, @selector(weakObj));
}



@end
