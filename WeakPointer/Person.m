//
//  Person.m
//  weakPointer
//
//  Created by LL on 2023/12/27.
//

#import "Person.h"

#import "lil_objc_weak.h"
#import "lil_objc_category_weak.h"

@implementation Person

- (void)dealloc {
    NSLog(@"%s", __func__);
    
//    if (是否有弱引用) {
        lil_weak_clear_no_lock(self);
//    }
}

@end


@implementation TestObject

- (void)dealloc {
    NSLog(@"%s", __func__);
    
//    if (是否有弱引用) {
        lil_weak_category_clear_no_lock(self);
//    }
}

@end
