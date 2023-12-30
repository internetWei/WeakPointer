//
//  lil_objc_category_weak.h
//  weakPointer
//
//  Created by LL on 2023/12/27.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

uintptr_t lil_objc_category_storeWeak(id referent, char *propertyName, id newObj);

void lil_weak_category_clear_no_lock(id referent_id);

NS_ASSUME_NONNULL_END
