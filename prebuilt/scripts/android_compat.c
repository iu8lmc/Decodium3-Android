/*
 * Android Bionic compatibility shim for glibc-linked ARM libraries.
 *
 * libgfortran.a from ARM GNU Toolchain is built against glibc.
 * Android uses Bionic libc which has different symbol names.
 * This file provides the missing glibc symbols mapped to Bionic equivalents.
 */

#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <math.h>
#include <assert.h>
#include <stdio.h>

/* ============================================================
 * glibc errno: __errno_location() -> Bionic __errno()
 * ============================================================ */
extern int *__errno(void);  /* Bionic's version */

int *__errno_location(void) {
    return __errno();
}

/* ============================================================
 * glibc ctype locale functions
 * These return pointers to thread-local ctype tables.
 * We provide a simple C-locale implementation.
 * ============================================================ */

/* glibc ctype bit flags */
#define _ISupper    0x0100
#define _ISlower    0x0200
#define _ISalpha    0x0400
#define _ISdigit    0x0800
#define _ISxdigit   0x1000
#define _ISspace    0x2000
#define _ISprint    0x4000
#define _ISgraph    0x8000
#define _ISblank    0x0001
#define _IScntrl    0x0002
#define _ISpunct    0x0004
#define _ISalnum    0x0008

static const unsigned short ctype_table[384] = {
    /* -128..-1: high bytes, all zero for C locale */
    [128+ 0] = _IScntrl,                          /* NUL */
    [128+ 1] = _IScntrl, [128+ 2] = _IScntrl, [128+ 3] = _IScntrl,
    [128+ 4] = _IScntrl, [128+ 5] = _IScntrl, [128+ 6] = _IScntrl,
    [128+ 7] = _IScntrl, [128+ 8] = _IScntrl,
    [128+ 9] = _IScntrl|_ISspace|_ISblank,         /* TAB */
    [128+10] = _IScntrl|_ISspace,                   /* LF */
    [128+11] = _IScntrl|_ISspace,                   /* VT */
    [128+12] = _IScntrl|_ISspace,                   /* FF */
    [128+13] = _IScntrl|_ISspace,                   /* CR */
    [128+14] = _IScntrl, [128+15] = _IScntrl, [128+16] = _IScntrl,
    [128+17] = _IScntrl, [128+18] = _IScntrl, [128+19] = _IScntrl,
    [128+20] = _IScntrl, [128+21] = _IScntrl, [128+22] = _IScntrl,
    [128+23] = _IScntrl, [128+24] = _IScntrl, [128+25] = _IScntrl,
    [128+26] = _IScntrl, [128+27] = _IScntrl, [128+28] = _IScntrl,
    [128+29] = _IScntrl, [128+30] = _IScntrl, [128+31] = _IScntrl,
    [128+32] = _ISspace|_ISprint|_ISblank,          /* SPACE */
    [128+33] = _ISpunct|_ISprint|_ISgraph,          /* ! */
    [128+34] = _ISpunct|_ISprint|_ISgraph,          /* " */
    [128+35] = _ISpunct|_ISprint|_ISgraph,          /* # */
    [128+36] = _ISpunct|_ISprint|_ISgraph,          /* $ */
    [128+37] = _ISpunct|_ISprint|_ISgraph,          /* % */
    [128+38] = _ISpunct|_ISprint|_ISgraph,          /* & */
    [128+39] = _ISpunct|_ISprint|_ISgraph,          /* ' */
    [128+40] = _ISpunct|_ISprint|_ISgraph,          /* ( */
    [128+41] = _ISpunct|_ISprint|_ISgraph,          /* ) */
    [128+42] = _ISpunct|_ISprint|_ISgraph,          /* * */
    [128+43] = _ISpunct|_ISprint|_ISgraph,          /* + */
    [128+44] = _ISpunct|_ISprint|_ISgraph,          /* , */
    [128+45] = _ISpunct|_ISprint|_ISgraph,          /* - */
    [128+46] = _ISpunct|_ISprint|_ISgraph,          /* . */
    [128+47] = _ISpunct|_ISprint|_ISgraph,          /* / */
    [128+48] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,  /* 0 */
    [128+49] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+50] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+51] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+52] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+53] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+54] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+55] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+56] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+57] = _ISdigit|_ISxdigit|_ISprint|_ISgraph|_ISalnum,  /* 9 */
    [128+58] = _ISpunct|_ISprint|_ISgraph,          /* : */
    [128+59] = _ISpunct|_ISprint|_ISgraph,          /* ; */
    [128+60] = _ISpunct|_ISprint|_ISgraph,          /* < */
    [128+61] = _ISpunct|_ISprint|_ISgraph,          /* = */
    [128+62] = _ISpunct|_ISprint|_ISgraph,          /* > */
    [128+63] = _ISpunct|_ISprint|_ISgraph,          /* ? */
    [128+64] = _ISpunct|_ISprint|_ISgraph,          /* @ */
    [128+65] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum, /* A */
    [128+66] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+67] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+68] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+69] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+70] = _ISupper|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum, /* F */
    [128+71] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+72] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+73] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+74] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+75] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+76] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+77] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+78] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+79] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+80] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+81] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+82] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+83] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+84] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+85] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+86] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+87] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+88] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+89] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+90] = _ISupper|_ISalpha|_ISprint|_ISgraph|_ISalnum, /* Z */
    [128+91] = _ISpunct|_ISprint|_ISgraph,
    [128+92] = _ISpunct|_ISprint|_ISgraph,
    [128+93] = _ISpunct|_ISprint|_ISgraph,
    [128+94] = _ISpunct|_ISprint|_ISgraph,
    [128+95] = _ISpunct|_ISprint|_ISgraph,
    [128+96] = _ISpunct|_ISprint|_ISgraph,
    [128+97] = _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum, /* a */
    [128+98] = _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+99] = _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+100]= _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+101]= _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum,
    [128+102]= _ISlower|_ISalpha|_ISxdigit|_ISprint|_ISgraph|_ISalnum, /* f */
    [128+103]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+104]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+105]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+106]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+107]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+108]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+109]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+110]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+111]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+112]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+113]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+114]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+115]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+116]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+117]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+118]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+119]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+120]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+121]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum,
    [128+122]= _ISlower|_ISalpha|_ISprint|_ISgraph|_ISalnum, /* z */
    [128+123]= _ISpunct|_ISprint|_ISgraph,
    [128+124]= _ISpunct|_ISprint|_ISgraph,
    [128+125]= _ISpunct|_ISprint|_ISgraph,
    [128+126]= _ISpunct|_ISprint|_ISgraph,
    [128+127]= _IScntrl,  /* DEL */
};

static const unsigned short *ctype_table_ptr = &ctype_table[128];

const unsigned short **__ctype_b_loc(void) {
    return &ctype_table_ptr;
}

/* tolower/toupper tables */
static int tolower_table[384];
static int toupper_table[384];
static int tables_init = 0;

static void init_case_tables(void) {
    if (tables_init) return;
    for (int i = 0; i < 384; i++) {
        int c = i - 128;
        tolower_table[i] = (c >= 'A' && c <= 'Z') ? c + 32 : c;
        toupper_table[i] = (c >= 'a' && c <= 'z') ? c - 32 : c;
    }
    tables_init = 1;
}

static const int *tolower_ptr;
static const int *toupper_ptr;

const int **__ctype_tolower_loc(void) {
    init_case_tables();
    tolower_ptr = &tolower_table[128];
    return &tolower_ptr;
}

const int **__ctype_toupper_loc(void) {
    init_case_tables();
    toupper_ptr = &toupper_table[128];
    return &toupper_ptr;
}

/* ============================================================
 * secure_getenv - glibc extension, falls back to getenv
 * ============================================================ */
char *secure_getenv(const char *name) {
    return getenv(name);
}

/* ============================================================
 * __assert_fail - glibc assert implementation
 * ============================================================ */
void __assert_fail(const char *assertion, const char *file,
                   unsigned int line, const char *function) {
    fprintf(stderr, "Assertion failed: %s (%s:%u, %s)\n",
            assertion, file, line, function ? function : "?");
    abort();
}

/* ============================================================
 * __isoc23_strtol - C23 strtol, just call strtol
 * ============================================================ */
long __isoc23_strtol(const char *nptr, char **endptr, int base) {
    return strtol(nptr, endptr, base);
}

/* ============================================================
 * OpenMP stubs (single-threaded fallback)
 * ============================================================ */
void GOMP_critical_name_start(void **pptr) { (void)pptr; }
void GOMP_critical_name_end(void **pptr)   { (void)pptr; }

/* ============================================================
 * GCC vectorized math stub: _ZGVnN4v_cosf
 * ARM NEON vectorized cosf (4 x float32)
 * ============================================================ */
#include <arm_neon.h>

float32x4_t _ZGVnN4v_cosf(float32x4_t x) {
    float r[4];
    float v[4];
    vst1q_f32(v, x);
    r[0] = cosf(v[0]);
    r[1] = cosf(v[1]);
    r[2] = cosf(v[2]);
    r[3] = cosf(v[3]);
    return vld1q_f32(r);
}

/* ============================================================
 * FFTW3 Fortran interface wrappers (sfftw_* -> fftwf_*)
 * Fortran passes all arguments by reference (pointers).
 * Name mangling: gfortran appends underscore.
 * ============================================================ */
#include <stdint.h>

/* Opaque FFTW plan type */
typedef void *fftwf_plan;
typedef float fftwf_complex[2];

/* FFTW C API declarations */
extern fftwf_plan fftwf_plan_dft_1d(int n, fftwf_complex *in,
    fftwf_complex *out, int sign, unsigned flags);
extern fftwf_plan fftwf_plan_dft_r2c_1d(int n, float *in,
    fftwf_complex *out, unsigned flags);
extern fftwf_plan fftwf_plan_dft_c2r_1d(int n, fftwf_complex *in,
    float *out, unsigned flags);
extern void fftwf_execute(const fftwf_plan p);
extern void fftwf_destroy_plan(fftwf_plan p);

/* Fortran wrappers (all args by reference) */
void sfftw_plan_dft_1d_(fftwf_plan *p, const int *n,
    fftwf_complex *in, fftwf_complex *out,
    const int *sign, const unsigned *flags) {
    *p = fftwf_plan_dft_1d(*n, in, out, *sign, *flags);
}

void sfftw_plan_dft_r2c_1d_(fftwf_plan *p, const int *n,
    float *in, fftwf_complex *out, const unsigned *flags) {
    *p = fftwf_plan_dft_r2c_1d(*n, in, out, *flags);
}

void sfftw_plan_dft_c2r_1d_(fftwf_plan *p, const int *n,
    fftwf_complex *in, float *out, const unsigned *flags) {
    *p = fftwf_plan_dft_c2r_1d(*n, in, out, *flags);
}

void sfftw_execute_(const fftwf_plan *p) {
    fftwf_execute(*p);
}

void sfftw_destroy_plan_(fftwf_plan *p) {
    fftwf_destroy_plan(*p);
}
