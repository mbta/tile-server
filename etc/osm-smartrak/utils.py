import os
import shutil

def copy_tree(src, dst, ignores=()):
    """Copy an entire directory tree 'src' to a new location 'dst'.

    Both 'src' and 'dst' must be directory names.  If 'src' is not a
    directory, raise OSError.  If 'dst' does not exist, it is
    created automatically.  The end result of the copy is that every
    file in 'src' is copied to 'dst', and directories under 'src' are
    recursively copied to 'dst'.  Return the list of files that were
    copied or might have been copied, using their output name.
    
    Ignore any file whose name is in the "ignores" iterable.

    This helper supports ignoring selected files and skips symlinks.
    """
    if not os.path.isdir(src):
        raise OSError("cannot copy tree '%s': not a directory" % src)

    names = os.listdir(src)
    os.makedirs(dst, exist_ok=True)

    outputs = []

    for n in names:
        if n in ignores: continue

        src_name = os.path.join(src, n)
        dst_name = os.path.join(dst, n)

#def copy_tree(src, dst, preserve_mode=1, preserve_times=1,
#              preserve_symlinks=0, update=0, verbose=1, dry_run=0):

        if os.path.islink(src_name):
            continue
        elif os.path.isdir(src_name):
            outputs.extend(copy_tree(src_name, dst_name, ignores))
        else:
            shutil.copy2(src_name, dst_name)
            outputs.append(dst_name)

    return outputs
