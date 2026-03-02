! Minimal omp_lib stub for ARM64 cross-compilation.
! The ARM GNU Toolchain doesn't ship omp_lib.mod for Fortran.
! This provides the module interface so files that "use omp_lib" compile.
! OpenMP runtime functions return single-threaded defaults.
module omp_lib
  implicit none

  integer, parameter :: omp_lock_kind = 4
  integer, parameter :: omp_nest_lock_kind = 8
  integer, parameter :: omp_sched_kind = 4

  interface
    function omp_get_num_threads() result(n)
      integer :: n
    end function
    function omp_get_thread_num() result(n)
      integer :: n
    end function
    function omp_get_max_threads() result(n)
      integer :: n
    end function
    function omp_get_wtime() result(t)
      double precision :: t
    end function
  end interface
end module omp_lib
