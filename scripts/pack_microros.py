#!/usr/bin/env python3
"""Pack micro-ROS static libraries into a single libmicroros.a."""
import os, sys, shutil, subprocess, tempfile, glob as glob_mod


def fix_merge_install_nesting(include_dir):
    """Unwrap one level of double-nesting caused by colcon --merge-install.

    --merge-install produces e.g. include/rcl/rcl/rcl.h instead of the
    expected include/rcl/rcl.h.  For every top-level subdirectory <pkg>
    that contains a same-named <pkg>/<pkg> child, move the child's
    contents up one level.
    """
    for entry in os.listdir(include_dir):
        entry_path = os.path.join(include_dir, entry)
        if not os.path.isdir(entry_path):
            continue
        inner = os.path.join(entry_path, entry)
        if os.path.isdir(inner):
            for f in os.listdir(inner):
                shutil.move(os.path.join(inner, f), os.path.join(entry_path, f))
            os.rmdir(inner)


installdir = sys.argv[1]
output_lib = sys.argv[2]
include_src = sys.argv[3]
include_dst = sys.argv[4]
ar_tool = sys.argv[5]
ranlib_tool = sys.argv[6]

a_files = sorted(glob_mod.glob(os.path.join(installdir, '**', '*.a'), recursive=True))
if not a_files:
    print('ERROR: No .a files found in', installdir, file=sys.stderr)
    print('       colcon build may have failed', file=sys.stderr)
    sys.exit(1)

# Skip if output is up to date
if os.path.exists(output_lib):
    out_mtime = os.path.getmtime(output_lib)
    if all(os.path.getmtime(f) <= out_mtime for f in a_files):
        print('libmicroros.a is up to date')
        # Header sync (fast path — still check if include dir needs updating)
        if os.path.isdir(include_src) and (not os.path.isdir(include_dst) or
                os.path.getmtime(include_src) > os.path.getmtime(include_dst)):
            if os.path.exists(include_dst):
                shutil.rmtree(include_dst)
            shutil.copytree(include_src, include_dst)
            for root, dirs, files in os.walk(include_dst, topdown=False):
                for f in files:
                    if not f.endswith(('.h', '.hpp')):
                        os.remove(os.path.join(root, f))
                if not os.listdir(root):
                    os.rmdir(root)
            fix_merge_install_nesting(include_dst)
        sys.exit(0)

# Flatten .a files into a temp directory
tmpdir = tempfile.mkdtemp()
try:
    for i, a_file in enumerate(a_files):
        sub = os.path.join(tmpdir, str(i))
        os.mkdir(sub)
        subprocess.run([ar_tool, 'x', a_file], cwd=sub, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for f in os.listdir(sub):
            os.replace(os.path.join(sub, f), os.path.join(tmpdir, f'{i:04d}_{f}'))
        os.rmdir(sub)

    objs = sorted(f for f in os.listdir(tmpdir) if f.endswith(('.o', '.obj')))
    if not objs:
        print('ERROR: No object files extracted from .a archives', file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(output_lib), exist_ok=True)
    subprocess.run([ar_tool, 'rc', output_lib] + objs, cwd=tmpdir, check=True)
    subprocess.run([ranlib_tool, output_lib], check=True)

    # Copy headers
    if os.path.isdir(include_src):
        if os.path.exists(include_dst):
            shutil.rmtree(include_dst)
        shutil.copytree(include_src, include_dst)
        for root, dirs, files in os.walk(include_dst, topdown=False):
            for f in files:
                if not f.endswith(('.h', '.hpp')):
                    os.remove(os.path.join(root, f))
            if not os.listdir(root):
                os.rmdir(root)
        fix_merge_install_nesting(include_dst)
finally:
    shutil.rmtree(tmpdir)
