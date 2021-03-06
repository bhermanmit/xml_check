program = xml 
prefix = /usr/local

source = $(wildcard *.F90)
objects = $(source:.F90=.o)
xml_lib = -Lfox-xml/lib -lxml

#===============================================================================
# User Options
#===============================================================================

COMPILER = gnu
DEBUG    = no
PROFILE  = no
OPTIMIZE = no
MPI      = no
HDF5     = no
PETSC    = no

#===============================================================================
# External Library Paths
#===============================================================================

MPI_DIR   = /opt/mpich/3.0.4-$(COMPILER)
HDF5_DIR  = /opt/hdf5/1.8.11-$(COMPILER)
PHDF5_DIR = /opt/phdf5/1.8.11-$(COMPILER)
PETSC_DIR = /opt/petsc/3.4.2-$(COMPILER)

#===============================================================================
# Add git SHA-1 hash
#===============================================================================

GIT_SHA1 = $(shell git log -1 2>/dev/null | head -n 1 | awk '{print $$2}')

#===============================================================================
# GNU Fortran compiler options
#===============================================================================

ifeq ($(COMPILER),gnu)
  F90 = gfortran
  F90FLAGS := -cpp -fbacktrace
  LDFLAGS =

  # Debugging
  ifeq ($(DEBUG),yes)
    F90FLAGS += -g -Wall -pedantic -std=f2008 -fbounds-check \
                -ffpe-trap=invalid,overflow,underflow
    LDFLAGS  += -g
  endif

  # Profiling
  ifeq ($(PROFILE),yes)
    F90FLAGS += -pg
    LDFLAGS  += -pg
  endif

  # Optimization
  ifeq ($(OPTIMIZE),yes)
    F90FLAGS += -O3
  endif
endif

#===============================================================================
# Intel Fortran compiler options
#===============================================================================

ifeq ($(COMPILER),intel)
  F90 = ifort
  F90FLAGS := -fpp -warn -assume byterecl -traceback
  LDFLAGS =

  # Debugging
  ifeq ($(DEBUG),yes)
    F90FLAGS += -g -ftrapuv -fp-stack-check -check all -fpe0
    LDFLAGS  += -g
  endif

  # Profiling
  ifeq ($(PROFILE),yes)
    F90FLAGS += -pg
    LDFLAGS  += -pg
  endif

  # Optimization
  ifeq ($(OPTIMIZE),yes)
    F90FLAGS += -O3
  endif
endif

#===============================================================================
# PGI compiler options
#===============================================================================

ifeq ($(COMPILER),pgi)
  F90 = pgf90
  F90FLAGS := -Mpreprocess -DNO_F2008 -Minform=inform -traceback
  LDFLAGS =

  # Debugging
  ifeq ($(DEBUG),yes)
    F90FLAGS += -g -Mbounds -Mchkptr -Mchkstk
    LDFLAGS  += -g
  endif

  # Profiling
  ifeq ($(PROFILE),yes)
    F90FLAGS += -pg
    LDFLAGS  += -pg
  endif

  # Optimization
  ifeq ($(OPTIMIZE),yes)
    F90FLAGS += -fast -Mipa
  endif
endif

#===============================================================================
# IBM XL compiler options
#===============================================================================

ifeq ($(COMPILER),ibm)
  F90 = xlf2003
  F90FLAGS := -WF,-DNO_F2008 -O2

  # Debugging
  ifeq ($(DEBUG),yes)
    F90FLAGS += -g -C -qflag=i:i -u
    LDFLAGS  += -g
  endif

  # Profiling
  ifeq ($(PROFILE),yes)
    F90FLAGS += -p
    LDFLAGS  += -p
  endif

  # Optimization
  ifeq ($(OPTIMIZE),yes)
    F90FLAGS += -O3
  endif
endif

#===============================================================================
# Cray compiler options
#===============================================================================

ifeq ($(COMPILER),cray)
  F90 = ftn
  F90FLAGS := -e Z -m 0

  # Debugging
  ifeq ($(DEBUG),yes)
    F90FLAGS += -g -R abcnsp -O0
    LDFLAGS  += -g
  endif
endif

#===============================================================================
# Setup External Libraries
#===============================================================================

# MPI for distributed-memory parallelism and HDF5 for I/O

ifeq ($(MPI),yes)
  ifeq ($(HDF5),yes)
    F90 = $(PHDF5_DIR)/bin/h5pfc
    F90FLAGS += -DHDF5
  else
    F90 = $(MPI_DIR)/bin/mpif90
  endif
  F90FLAGS += -DMPI
else
  ifeq ($(HDF5),yes)
    F90 = $(HDF5_DIR)/bin/h5fc
    F90FLAGS += -DHDF5
  endif
endif

# PETSC for CMFD functionality

ifeq ($(PETSC),yes)
  # Check to make sure MPI is set
  ifneq ($(MPI),yes)
    $(error MPI must be enabled to compile with PETSC!)
  endif

  # Set up PETSc environment
  include $(PETSC_DIR)/conf/petscvariables
  F90FLAGS += -I$(PETSC_DIR)/include -DPETSC
  LDFLAGS += $(PETSC_LIB)
endif

#===============================================================================
# Machine-specific setup
#===============================================================================

# IBM Blue Gene/P ANL supercomputer

ifeq ($(MACHINE),bluegene)
  F90 = /bgsys/drivers/ppcfloor/comm/xl/bin/mpixlf2003
  F90FLAGS = -WF,-DNO_F2008,-DMPI -O3
  LDFLAGS = -lmpich.cnkf90
endif

# Cray XK6 ORNL Titan supercomputer

ifeq ($(MACHINE),crayxk6)
  F90 = ftn
  F90FLAGS += -DMPI
endif

# IBM Blue Gene/Q ANL supercomputer

ifeq ($(MACHINE),bluegeneq)
  F90 = mpixlf2003
  F90FLAGS = -WF,-DNO_F2008,-DMPI -O5
endif

#===============================================================================
# Targets
#===============================================================================

all: fox-xml $(program)
fox-xml:
	cd fox-xml; make MACHINE=$(MACHINE) F90=$(F90) F90FLAGS="$(F90FLAGS)"
$(program): $(objects)
	$(F90) $(objects) $(xml_lib) $(LDFLAGS) -o $@
distclean: clean
	cd fox-xml; make clean
clean:
	@rm -f *.o *.mod $(program)
neat:
	@rm -f *.o *.mod

#===============================================================================
# Rules
#===============================================================================

.SUFFIXES: .F90 .o
.PHONY: all fox-xml clean neat distclean 

%.o: %.F90
	$(F90) $(F90FLAGS) -DGIT_SHA1="\"$(GIT_SHA1)\"" -Ifox-xml/include -c $<
