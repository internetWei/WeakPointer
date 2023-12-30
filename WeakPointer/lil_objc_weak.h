//
//  lil_objc_weak.h
//  weakPointer
//
//  Created by LL on 2023/12/22.
//

#import <Foundation/Foundation.h>

uintptr_t lil_objc_storeWeak(void **location, id newObj);

void lil_weak_clear_no_lock(id referent_id);
