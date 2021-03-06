!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2018  DFTB+ developers group                                                      !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

#:include 'common.fypp'

!> Contains fundamental global computing environment settings.
!>
!> It contains global settings and routines, which can be used already before the parsing of the
!> input has taken place and the details of the user settings for the running-environment are
!> known. Also, it can be used by routines which are not MPI-aware but wish to make I/O or abort the
!> code.
!>
module globalenv
  use, intrinsic :: iso_fortran_env, only : output_unit
#:if WITH_MPI
  use mpifx
#:endif
  implicit none
  private

  public :: initGlobalEnv, destructGlobalEnv
  public :: abortProgram, shutdown, synchronizeAll
  public :: stdOut, tIoProc
  public :: withScalapack, withMpi

  !> Standard out file handler
  integer, protected :: stdOut

  !> Whether current process is the global master process
  logical, protected :: tIoProc = .true.

#:if WITH_MPI
  !> Global MPI communicator (used for aborts)
  type(mpifx_comm), protected :: globalMpiComm
#:endif

  !> Unredirected standard out
  integer, parameter :: stdOut0 = output_unit

  !> Whether code was compiled with MPI support
  logical, parameter :: withMpi = ${FORTRAN_LOGICAL(WITH_MPI)}$

  !> Whether code was compiled with Scalapack
  logical, parameter :: withScalapack = ${FORTRAN_LOGICAL(WITH_SCALAPACK)}$



contains

  !> Initializes global environment (must be the first statement of a program)
  subroutine initGlobalEnv()

  #:if WITH_MPI
    call mpifx_init_thread(requiredThreading=MPI_THREAD_FUNNELED)
    call globalMpiComm%init()
    if (globalMpiComm%master) then
      stdOut = stdOut0
    else
      stdOut = 1
      open(stdOut, file="/dev/null", action="write")
    end if
    tIoProc = globalMpiComm%master
  #:else
    stdOut = stdOut0
  #:endif

  end subroutine initGlobalEnv


  !> Finalizes global environment (must be the last statement of a program)
  subroutine destructGlobalEnv()

  #:if WITH_MPI
    call mpifx_finalize()
  #:endif

  end subroutine destructGlobalEnv


  !> Gracefully shuts down environment and stops execution.
  !>
  !> Note: this routine must be called collectively by all processes.
  !>
  subroutine shutdown()

    call synchronizeAll()
    call destructGlobalEnv()
    stop

  end subroutine shutdown


  !> Aborts program execution immediately.
  !>
  !> Note: if this routine is called by any the processes, execution immediately stops
  !> without waiting for any other processes.
  !>
  subroutine abortProgram(errorCode)

    !> Error code to emit (default: 1)
    integer, intent(in), optional :: errorCode

    integer :: errorCode0
  #:if WITH_MPI
    integer :: error
  #:endif

    if (.not. present(errorCode)) then
      errorCode0 = 1
    else
      errorCode0 = errorCode
    end if

  #:if WITH_MPI
    call mpifx_abort(globalMpiComm, errorCode0, error)
    if (error /= 0) then
      write(stdOut0, "(A,I0,A)") "Process ", globalMpiComm%rank, " could not be aborted."
    end if
  #:endif
    stop

  end subroutine abortProgram


  !> Waits until all processes reach this point
  subroutine synchronizeAll()

  #:if WITH_MPI
    call mpifx_barrier(globalMpiComm)
  #:endif

  end subroutine synchronizeAll


end module globalenv
