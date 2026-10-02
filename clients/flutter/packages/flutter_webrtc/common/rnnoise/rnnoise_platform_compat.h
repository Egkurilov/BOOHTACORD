#ifndef BOOHTA_RNNOISE_PLATFORM_COMPAT_H_
#define BOOHTA_RNNOISE_PLATFORM_COMPAT_H_

#include <stddef.h>

#ifdef _MSC_VER
#include <malloc.h>
#define RNNOISE_ALLOCA _alloca
#define RNNOISE_HAS_STACK_ALLOCA 1
#elif defined(RNNOISE_TEST_STACK_ALLOCA)
#include <alloca.h>
#define RNNOISE_ALLOCA alloca
#define RNNOISE_HAS_STACK_ALLOCA 1
#endif

#ifdef RNNOISE_HAS_STACK_ALLOCA
#define RNNOISE_STACK_ARRAY(type, name, count) \
  type* name = (type*)RNNOISE_ALLOCA(sizeof(type) * (size_t)(count))
#else
#define RNNOISE_STACK_ARRAY(type, name, count) type name[(count)]
#endif

#endif  // BOOHTA_RNNOISE_PLATFORM_COMPAT_H_
