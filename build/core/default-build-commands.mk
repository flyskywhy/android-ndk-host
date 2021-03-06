# The following definitions are the defaults used by all toolchains.
# This is included in setup-toolchain.mk just before the inclusion
# of the toolchain's specific setup.mk file which can then override
# these definitions.
#

# These flags are used to ensure that a binary doesn't reference undefined
# flags.
TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

# These flags are used to enfore the NX (no execute) security feature in the
# generated machine code. This adds a special section to the generated shared
# libraries that instruct the Linux kernel to disable code execution from
# the stack and the heap.
TARGET_NO_EXECUTE_CFLAGS  := -Wa,--noexecstack
TARGET_NO_EXECUTE_LDFLAGS := -Wl,-z,noexecstack

# NOTE: Ensure that TARGET_LIBGCC is placed after all private objects
#       and static libraries, but before any other library in the link
#       command line when generating shared libraries and executables.
#
#       This ensures that all libgcc.a functions required by the target
#       will be included into it, instead of relying on what's available
#       on other libraries like libc.so, which may change between system
#       releases due to toolchain or library changes.
#
define cmd-build-shared-library
$(PRIVATE_CXX) \
    -nostdlib -Wl,-soname,$(notdir $@) \
    -Wl,-shared,-Bsymbolic \
    $(call host-path,\
        $(TARGET_CRTBEGIN_SO_O) \
        $(PRIVATE_OBJECTS)) \
    $(call link-whole-archives,$(PRIVATE_WHOLE_STATIC_LIBRARIES))\
    $(call host-path,\
        $(PRIVATE_STATIC_LIBRARIES) \
        $(PRIVATE_LIBGCC) \
        $(PRIVATE_SHARED_LIBRARIES)) \
    $(PRIVATE_LDFLAGS) \
    $(PRIVATE_LDLIBS) \
    $(call host-path,\
        $(TARGET_CRTEND_SO_O)) \
    -o $(call host-path,$@)
endef

define cmd-build-executable
$(PRIVATE_CXX) \
    -nostdlib -Bdynamic \
    -Wl,-dynamic-linker,/system/bin/linker \
    -Wl,--gc-sections \
    -Wl,-z,nocopyreloc \
    $(call host-path,\
        $(TARGET_CRTBEGIN_DYNAMIC_O) \
        $(PRIVATE_OBJECTS)) \
    $(call link-whole-archives,$(PRIVATE_WHOLE_STATIC_LIBRARIES))\
    $(call host-path,\
        $(PRIVATE_STATIC_LIBRARIES) \
        $(PRIVATE_LIBGCC) \
        $(PRIVATE_SHARED_LIBRARIES)) \
    $(PRIVATE_LDFLAGS) \
    $(PRIVATE_LDLIBS) \
    $(call host-path,\
        $(TARGET_CRTEND_O)) \
    -o $(call host-path,$@)
endef

define cmd-build-static-library
$(PRIVATE_AR) $(call host-path,$@) $(call host-path,$(PRIVATE_OBJECTS))
endef

# The strip command is only used for shared libraries and executables.
# It is thus safe to use --strip-unneeded, which is only dangerous
# when applied to static libraries or object files.
cmd-strip = $(PRIVATE_STRIP) --strip-unneeded $(call host-path,$1)

$(LOCAL_my)_LIBGCC = $(shell $($(LOCAL_my)_CC) -print-libgcc-file-name)
$(LOCAL_my)_LDLIBS := -lc -lm

#
# IMPORTANT: The following definitions must use lazy assignment because
# the value of TOOLCHAIN_PREFIX or TARGET_CFLAGS can be changed later by
# the toolchain's setup.mk script.
#

TARGET_CC       = $(TOOLCHAIN_PREFIX)gcc
TARGET_CFLAGS   =

TARGET_CXX      = $(TOOLCHAIN_PREFIX)g++
TARGET_CXXFLAGS = $(TARGET_CFLAGS) -fno-exceptions -fno-rtti

TARGET_LD       = $(TOOLCHAIN_PREFIX)ld
TARGET_LDFLAGS :=

TARGET_AR       = $(TOOLCHAIN_PREFIX)ar
TARGET_ARFLAGS := crs

TARGET_STRIP    = $(TOOLCHAIN_PREFIX)strip

#
# host toolchain
#

HOST_CC       = gcc
HOST_CFLAGS   =

HOST_CXX      = g++
HOST_CXXFLAGS = $(HOST_CFLAGS) -fno-exceptions -fno-rtti

HOST_LD       = ld
HOST_LDFLAGS :=

HOST_AR       = ar
HOST_ARFLAGS := crs

HOST_STRIP    = strip

###########################################################
## Commands for running host ar
###########################################################

define cmd-build-host-static-library
$(PRIVATE_AR) $(call host-path,$@) $(call host-path,$(PRIVATE_ALL_OBJECTS))
endef

###########################################################
## Commands for running gcc to link a host executable
###########################################################

ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-executable-inner
$(PRIVATE_CXX) \
	-Wl,-rpath-link=$(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../lib \
	$(HOST_GLOBAL_LD_DIRS) \
	$(PRIVATE_LDFLAGS) \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
		$(HOST_GLOBAL_LDFLAGS) \
	) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-executable
@mkdir -p $(dir $@)
$(hide) $(transform-host-o-to-executable-inner)
endef
