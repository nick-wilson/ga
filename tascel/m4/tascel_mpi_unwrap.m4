# TASCEL_MPI_UNWRAP()
# ---------------
# Attempt to unwrap the MPI compiler for the current language and determine
# the underlying compiler.
#
# The strategy is to first compare the stdout of the version flags using
# a custom perl script.  Next we combine stdout and sterr for the comparison.
# Occasionally, the MPI compiler will always report a non-zero exit status.
# That is the last case checked for.
AC_DEFUN([TASCEL_MPI_UNWRAP], [
# Find perl.
AC_PATH_PROG([PERL], [perl])
# Create inside.pl.
rm -f inside.pl
[cat >inside.pl <<"EOF"
#!/usr/bin/perl
$numargs = @S|@#ARGV + 1;
if ($numargs != 2) {
    print "Usage: wrapped.txt naked.txt\n";
    exit 1;
}
# Read each input file as a string (rather than a list).
local $/=undef;
open WRAPPED, "$ARGV[0]" or die "Could not open wrapped text file: $!";
$wrapped_lines = <WRAPPED>;
close WRAPPED;
open NAKED, "$ARGV[1]" or die "Could not open naked text file: $!";
$naked_lines = <NAKED>;
close NAKED;
# Replace newlines, + from wrapped and naked lines.
$wrapped_lines =~ tr/\n+/ /;
$naked_lines =~ tr/\n+/ /;
# Remove whitespace from beginning of wrapped and naked lines.
$wrapped_lines =~ s/^\s+//;
$naked_lines =~ s/^\s+//;
# Remove whitespace from end of wrapped and naked lines.
$wrapped_lines =~ s/\s+$//;
$naked_lines =~ s/\s+$//;
# If either wrapped_lines or naked_lines are empty, this is an error.
# It is assumed that the particular version string which created the input
# files should generate SOMETHING.
unless ($wrapped_lines) {
    exit 1;
}
unless ($naked_lines) {
    exit 1;
}
# Can the naked lines be found within the wrapped lines?
if ($wrapped_lines =~ /$naked_lines/) {
    #print "Found as substring\n";
    exit 0;
}
# Are the naked lines exactly the same as the wrapped lines?
elsif ($wrapped_lines eq $naked_lines) {
    #print "Found equal\n";
    exit 0;
}
else {
    #print "Not found\n";
    exit 1;
}
EOF]
inside="$PERL inside.pl"
AC_LANG_CASE(
[C], [
    wrapped="$CC"
    AS_CASE([$wrapped],
        [*_r],  [compilers="bgxlc_r xlc_r"],
        [*],    [compilers="bgxlc xlc gcc pgcc pathcc icc ecc cl ccc cc"])
],
[C++], [
    wrapped="$CXX"
    AS_CASE([$wrapped],
        [*_r],  [compilers="bgxlC_r"],
        [*],    [compilers="g++ c++ icpc pgCC pathCC gpp aCC cxx cc++ cl.exe FCC KCC RCC bgxlC_r bgxlC xlC_r xlC CC"])
],
[Fortran 77], [
    wrapped="$F77"
    AS_CASE([$wrapped],
        [*_r],  [compilers="bgxlf95_r xlf95_r bgxlf90_r xlf90_r bgxlf_r xlf_r"],
        [*],    [compilers="gfortran g95 bgxlf95 xlf95 f95 fort ifort ifc efc pgf95 pathf95 lf95 bgxlf90 xlf90 f90 pgf90 pathf90 pghpf epcf90 g77 bgxlf xlf f77 frt pgf77 pathf77 cf77 fort77 fl32 af77"])
    ],
[Fortran], [
    wrapped="$FC"
])
AS_VAR_PUSHDEF([tascel_cv_mpi_naked], [tascel_cv_mpi[]_AC_LANG_ABBREV[]_naked])
AC_CACHE_CHECK([for base $wrapped compiler], [tascel_cv_mpi_naked], [
versions="--version -v -V -qversion"
found_wrapped_version=0
# Try separating stdout and stderr. Only compare stdout.
AS_IF([test "x$tascel_cv_mpi_naked" = x], [
echo "only comparing stdout" >&AS_MESSAGE_LOG_FD
for version in $versions
do
    echo "trying version=$version" >&AS_MESSAGE_LOG_FD
    rm -f mpi.txt mpi.err naked.txt naked.err
    AS_IF([$wrapped $version 1>mpi.txt 2>mpi.err],
        [found_wrapped_version=1
         for naked_compiler in $compilers
         do
            AS_IF([test "x$naked_compiler" != "x$wrapped"],
                [AS_IF([$naked_compiler $version 1>naked.txt 2>naked.err],
                    [AS_IF([$inside mpi.txt naked.txt >/dev/null],
                        [tascel_cv_mpi_naked=$naked_compiler; break],
                        [echo "inside.pl $wrapped $naked_compiler failed, skipping" >&AS_MESSAGE_LOG_FD])],
                    [echo "$naked_compiler $version failed, skipping" >&AS_MESSAGE_LOG_FD])])
         done],
        [echo "$wrapped $version failed, skipping" >&AS_MESSAGE_LOG_FD])
    AS_IF([test "x$tascel_cv_mpi_naked" != x], [break])
done
])
# Perhaps none of the MPI compilers had a zero exit status (this is bad).
# In this case we have to do a brute force match regardless of exit status.
AS_IF([test "x$found_wrapped_version" = x0], [
echo "no zero exit status found for MPI compilers" >&AS_MESSAGE_LOG_FD
AS_IF([test "x$tascel_cv_mpi_naked" = x], [
for version in $versions
do
    echo "trying version=$version" >&AS_MESSAGE_LOG_FD
    rm -f mpi.txt mpi.err
    $wrapped $version 1>mpi.txt 2>mpi.err
    for naked_compiler in $compilers
    do
        AS_IF([test "x$naked_compiler" != "x$wrapped"],
            [rm -f naked.txt naked.err
             AS_IF([$naked_compiler $version 1>naked.txt 2>naked.err],
                [AS_IF([$inside mpi.txt naked.txt >/dev/null],
                    [tascel_cv_mpi_naked=$naked_compiler; break],
                    [echo "inside.pl $wrapped $naked_compiler failed, skipping" >&AS_MESSAGE_LOG_FD])],
                [echo "$naked_compiler $version failed, skipping" >&AS_MESSAGE_LOG_FD])])
    done
    AS_IF([test "x$tascel_cv_mpi_naked" != x], [break])
done
])
])
# Try by combining stdout/err into one file.
AS_IF([test "x$tascel_cv_mpi_naked" = x], [
echo "try combining stdout and stderr into one file" >&AS_MESSAGE_LOG_FD
for version in $versions
do
    echo "trying version=$version" >&AS_MESSAGE_LOG_FD
    rm -f mpi.txt naked.txt
    AS_IF([$wrapped $version 1>mpi.txt 2>&1],
        [for naked_compiler in $compilers
         do
            AS_IF([test "x$naked_compiler" != "x$wrapped"],
                [AS_IF([$naked_compiler $version 1>naked.txt 2>&1],
                    [AS_IF([$inside mpi.txt naked.txt >/dev/null],
                        [tascel_cv_mpi_naked=$naked_compiler; break],
                        [echo "inside.pl $wrapped $naked_compiler failed, skipping" >&AS_MESSAGE_LOG_FD])],
                    [echo "$naked_compiler $version failed, skipping" >&AS_MESSAGE_LOG_FD])])
         done],
        [echo "$wrapped $version failed, skipping" >&AS_MESSAGE_LOG_FD])
    AS_IF([test "x$tascel_cv_mpi_naked" != x], [break])
done
])
# If we got this far, then it's likely that the MPI compiler had a zero exit
# status when it shouldn't have for one version flag, but later had a non-zero
# exit status for a flag it shouldn't have.  One false positive hid a false
# negative.  In this case, brute force compare all MPI compiler output against
# all compiler output.
AS_IF([test "x$tascel_cv_mpi_naked" = x], [
echo "we have a very badly behaving MPI compiler" >&AS_MESSAGE_LOG_FD
for version in $versions
do
    echo "trying version=$version" >&AS_MESSAGE_LOG_FD
    rm -f mpi.txt mpi.err
    $wrapped $version 1>mpi.txt 2>mpi.err
    for naked_compiler in $compilers
    do
        AS_IF([test "x$naked_compiler" != "x$wrapped"],
            [rm -f naked.txt naked.err
             AS_IF([$naked_compiler $version 1>naked.txt 2>naked.err],
                [AS_IF([$inside mpi.txt naked.txt >/dev/null],
                    [tascel_cv_mpi_naked=$naked_compiler; break],
                    [echo "inside.pl $wrapped $naked_compiler failed, skipping" >&AS_MESSAGE_LOG_FD])],
                [echo "$naked_compiler $version failed, skipping" >&AS_MESSAGE_LOG_FD])])
    done
    AS_IF([test "x$tascel_cv_mpi_naked" != x], [break])
done
])
rm -f mpi.txt mpi.err naked.txt naked.err
AS_IF([test "x$tascel_cv_mpi_naked" = x], [tascel_cv_mpi_naked=error])
])
AS_VAR_POPDEF([tascel_cv_mpi_naked])
rm -f inside.pl
AS_IF([test "x$tascel_cv_mpi_naked" = xerror],
    [AC_MSG_WARN([Could not determine the Fortran compiler wrapped by MPI])
     AC_MSG_WARN([This is usually okay])])
])dnl


# TASCEL_MPI_UNWRAP_PUSH()
# --------------------
# Set CC/CXX/F77/FC to their unwrapped MPI counterparts.
# Save their old values for restoring later.
AC_DEFUN([TASCEL_MPI_UNWRAP_PUSH], [
pagoda_mpi_unwrap_push_save_CC="$CC"
pagoda_mpi_unwrap_push_save_CXX="$CXX"
pagoda_mpi_unwrap_push_save_F77="$F77"
pagoda_mpi_unwrap_push_save_FC="$FC"
AS_IF([test "x$tascel_cv_mpic_naked"   != xerror], [ CC="$tascel_cv_mpic_naked"])
AS_IF([test "x$tascel_cv_mpicxx_naked" != xerror], [CXX="$tascel_cv_mpicxx_naked"])
AS_IF([test "x$tascel_cv_mpif77_naked" != xerror], [F77="$tascel_cv_mpif77_naked"])
AS_IF([test "x$tascel_cv_mpifc_naked"  != xerror], [ FC="$tascel_cv_mpifc_naked"])
])dnl


# TASCEL_MPI_UNWRAP_POP()
# -------------------
# Restore CC/CXX/F77/FC to their MPI counterparts.
AC_DEFUN([TASCEL_MPI_UNWRAP_POP], [
 CC="$pagoda_mpi_unwrap_push_save_CC"
CXX="$pagoda_mpi_unwrap_push_save_CXX"
F77="$pagoda_mpi_unwrap_push_save_F77"
 FC="$pagoda_mpi_unwrap_push_save_FC"
])dnl