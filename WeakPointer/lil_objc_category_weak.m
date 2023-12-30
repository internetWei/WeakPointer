//
//  lil_objc_category_weak.m
//  weakPointer
//
//  Created by LL on 2023/12/27.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define TABLE_SIZE(entry) (entry->mask ? entry->mask + 1 : 0)

typedef struct {
    uintptr_t referent;
    char *propertyName;
} weak_referrer_t;

typedef uintptr_t DisguisedPtr;

typedef struct {
    DisguisedPtr referent;
    weak_referrer_t *referrers;
    uintptr_t num_refs;
    uintptr_t mask;
    uintptr_t max_hash_displacement;
} weak_entry_t;
 
typedef struct {
    weak_entry_t *weak_entries;
    size_t num_entries;
    uintptr_t mask;
    uintptr_t max_hash_displacement;
} weak_table_t;

static weak_table_t _weak_table;

static inline uintptr_t hash_pointer(void *obj) {
    uintptr_t key = (uintptr_t)obj;
    key ^= key >> 4;
    key *= 0x8a970be7488fda55;
    key ^= __builtin_bswap64(key);
    return (uint32_t)key;
}


static inline uintptr_t hash_pointer2(void *obj1, void *obj2) {
    uintptr_t key = (uintptr_t)obj1 + (uintptr_t)obj2;
    key ^= key >> 4;
    key *= 0x8a970be7488fda55;
    key ^= __builtin_bswap64(key);
    return (uint32_t)key;
}


// 从 weak_table 中获取对象对应的弱引用表。
static weak_entry_t *
weak_entry_for_referent(weak_table_t *weak_table, void *referent_id) {
    weak_entry_t *weak_entries = weak_table->weak_entries;
    if (!weak_entries) { return NULL; }
    
    uintptr_t referent = (uintptr_t)referent_id;
    
    size_t begin = hash_pointer(referent_id) & weak_table->mask;
    size_t index = begin;
    size_t hash_displacement = 0;
    
    while (weak_entries[index].referent != referent) {
        index = (index + 1) & weak_table->mask;
        if (index == begin) { assert(0); }// 代码存在逻辑问题。
        hash_displacement += 1;
        if (hash_displacement > weak_table->max_hash_displacement) { return NULL; }
    }
    
    return &weak_entries[index];
}


// 从弱引用表中移除指定分类属性。
static void remove_referrer(weak_entry_t *entry, void *old_referrer_id, char *propertyName) {
    size_t begin = hash_pointer2(old_referrer_id, propertyName) & entry->mask;
    size_t index = begin;
    size_t hash_displacement = 0;
    uintptr_t old_referrer = (uintptr_t)old_referrer_id;
    
    while (entry->referrers[index].referent != old_referrer && 
           entry->referrers[index].propertyName != propertyName) {
        index = (index + 1) & entry->mask;
        if (index == begin) { assert(0); }// 代码存在逻辑问题。
        hash_displacement += 1;
        if (hash_displacement > entry->max_hash_displacement) {
            printf("试图删除一个未知的弱引用变量");
            assert(0);
            return;
        }
    }
    
    entry->referrers[index] = (weak_referrer_t){};
    entry->num_refs -= 1;
}


/// 从弱引用表中移除分类属性。
static void weak_unregister_no_lock(weak_table_t *weak_table, void *referent, char *propertyName, void *referrer) {
    weak_entry_t *entry;
    
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        remove_referrer(entry, referrer, propertyName);
    }
}


static void append_referrer(weak_entry_t *entry, void *new_referrer, char *propertyName);
// 对弱引用表进行扩容并插入分类属性。
__attribute__((noinline, used))
static void grow_refs_and_insert(weak_entry_t *entry, void *new_referrer, char *propertyName) {
    size_t old_size = TABLE_SIZE(entry);
    size_t new_size = old_size ? old_size * 2 : 8;
    
    size_t num_refs = entry->num_refs;
    weak_referrer_t *old_refs = entry->referrers;
    entry->mask = new_size - 1;
    
    entry->referrers = (weak_referrer_t *)calloc(TABLE_SIZE(entry), sizeof(weak_referrer_t));
    entry->num_refs = 0;
    entry->max_hash_displacement = 0;
    
    for (size_t i = 0; i < old_size && num_refs > 0; i++) {
        if (old_refs[i].referent != 0) {
            weak_referrer_t old_ref = old_refs[i];
            append_referrer(entry, (void *)old_ref.referent, old_ref.propertyName);
            num_refs -= 1;
        }
    }
    
    append_referrer(entry, new_referrer, propertyName);
    if (old_refs) { free(old_refs); }
}


// 将分类属性添加到弱引用表中。
static void append_referrer(weak_entry_t *entry, void *new_referrer, char *propertyName) {
    if (entry->num_refs >= TABLE_SIZE(entry) * 3/4) {
        return grow_refs_and_insert(entry, new_referrer, propertyName);
    }
    
    size_t begin = hash_pointer2(new_referrer, propertyName) & entry->mask;
    size_t index = begin;
    size_t hash_displacement = 0;
    
    while (entry->referrers[index].referent != 0) {
        hash_displacement += 1;
        index = (index + 1) & entry->mask;
        if (index == begin) { assert(0); }// 代码存在逻辑问题
    }
    
    if (hash_displacement > entry->max_hash_displacement) {
        entry->max_hash_displacement = hash_displacement;
    }
    
    entry->referrers[index] = (weak_referrer_t){(uintptr_t)new_referrer, propertyName};
    entry->num_refs += 1;
}


// 向 weak_table 中插入弱引用表。
static void weak_entry_insert(weak_table_t *weak_table, weak_entry_t *new_entry) {
    weak_entry_t *weak_entries = weak_table->weak_entries;
    
    size_t begin = hash_pointer((void *)new_entry->referent) & (weak_table->mask);
    size_t index = begin;
    size_t hash_displacement = 0;
    
    while (weak_entries[index].referent != 0) {
        index = (index + 1) & weak_table->mask;
        if (index == begin) { assert(0); }// 代码存在逻辑问题。
        hash_displacement += 1;
    }
    
    weak_entries[index] = *new_entry;
    weak_table->num_entries += 1;
    
    if (hash_displacement > weak_table->max_hash_displacement) {
        weak_table->max_hash_displacement = hash_displacement;
    }
}


// 调整 weak_table 的容量。
static void weak_resize(weak_table_t *weak_table, size_t new_size) {
    size_t old_size = TABLE_SIZE(weak_table);
    
    weak_entry_t *old_entries = weak_table->weak_entries;
    weak_entry_t *new_entries = (weak_entry_t *)calloc(new_size, sizeof(weak_entry_t));
    
    weak_table->mask = new_size - 1;
    weak_table->weak_entries = new_entries;
    weak_table->max_hash_displacement = 0;
    weak_table->num_entries = 0;
    
    if (!old_entries) { return; }
    
    weak_entry_t *entry;
    weak_entry_t *end = old_entries + old_size;
    
    for (entry = old_entries; entry < end; entry++) {
        if (entry->referent) {
            weak_entry_insert(weak_table, entry);
        }
    }
    
    free(old_entries);
}


// 对 weak_table 进行扩容。
static void weak_grow_maybe(weak_table_t *weak_table) {
    size_t old_size = TABLE_SIZE(weak_table);
    
    if (weak_table->num_entries >= old_size * 3/4) {
        weak_resize(weak_table, old_size ? old_size * 2 : 64);
    }
}


// 将分类属性添加到指定对象的弱引用表中。
static void weak_register_no_lock(weak_table_t *weak_table, void *referent, char *propertyName, void *referrer) {
    weak_entry_t *entry;
    if ((entry = weak_entry_for_referent(weak_table, referent))) {
        append_referrer(entry, referrer, propertyName);
    } else {
        weak_entry_t new_entry;
        new_entry.referent = (DisguisedPtr)referent;
        new_entry.referrers = calloc(8, sizeof(weak_referrer_t));
        new_entry.referrers[0] = (weak_referrer_t){(uintptr_t)referrer, propertyName};
        new_entry.num_refs = 1;
        new_entry.mask = 8 - 1;
        new_entry.max_hash_displacement = 0;
        
        weak_grow_maybe(weak_table);
        
        weak_entry_insert(weak_table, &new_entry);
    }
}


static void * storeWeak(void *referent, char *propertyName, void *newObj) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id oldObj = [(__bridge id)referent performSelector:sel_getUid(propertyName)];
#pragma clang diagnostic pop
    
    if (oldObj) {
        weak_unregister_no_lock(&_weak_table, (__bridge void *)oldObj, propertyName, referent);
    }
    
    if (newObj) {
        weak_register_no_lock(&_weak_table, newObj, propertyName, referent);
    }
    
    return newObj;
}


uintptr_t lil_objc_category_storeWeak(id referent, char *propertyName, id newObj) {
    return (uintptr_t)storeWeak((__bridge void *)referent, propertyName, (__bridge void *)newObj);
}


static void weak_compact_maybe(weak_table_t *weak_table) {
    size_t old_size = TABLE_SIZE(weak_table);
    
    if (old_size >= 1024 && old_size / 16 >= weak_table->num_entries) {
        weak_resize(weak_table, old_size / 8);
    }
}


// 将弱引用表从 weak_table 中移除。
static void weak_entry_remove(weak_table_t *weak_table, weak_entry_t *entry) {
    free(entry->referrers);
    memset(entry, 0, sizeof(*entry));
    
    weak_table->num_entries -= 1;
    
    weak_compact_maybe(weak_table);
}


void lil_weak_category_clear_no_lock(void *referent) {
    weak_entry_t *entry = weak_entry_for_referent(&_weak_table, referent);
    if (entry == NULL) { return; }
    
    weak_referrer_t *referrers = entry->referrers;
    size_t count = TABLE_SIZE(entry);
    
    for (size_t i = 0; i < count; i++) {
        weak_referrer_t referrer = referrers[i];
        if (referrer.referent == 0) { continue; }
        
        objc_setAssociatedObject((__bridge id)(void *)referrer.referent, sel_getUid(referrer.propertyName), nil, OBJC_ASSOCIATION_ASSIGN);
    }
    
    weak_entry_remove(&_weak_table, entry);
}
