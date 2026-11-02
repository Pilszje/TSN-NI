#!/bin/python
import sys
import fnmatch
import re
import os
from pathlib import Path

if len(sys.argv)>1:
    if (len(fnmatch.filter([sys.argv[1]], '*.f'))>0):
        # keep two lists, source files and dep files
        sourceFiles = set()
        depFiles = [os.path.realpath(sys.argv[1])]

        while len(depFiles)>0:
            # go to dir of path    
            with open(depFiles[0],'r') as dep:
                # print(depFiles[0])
                path = os.path.dirname(depFiles[0])
                # go to path of file
                for line in dep:
                    line = line.replace('\n','')
                    if line[-2:] == '.f': depFiles.append(os.path.realpath(path+'/'+line))
                    else:
                        sourceFiles.add(os.path.realpath(path+'/'+line))
                        # print("old: "+path+line)
                        # print("new: "+os.path.realpath(path+'/'+line))
                depFiles.pop(0)
        # print(len(sourceFiles))
        # print("after set: " + str(len(set(sourceFiles))))
        # for source in sourceFiles: print(source)
        # print("deps")
        # print(depFiles)
        with open('deps.f', 'w') as depsFile: depsFile.write('\n'.join(sourceFiles))
    
    else:
        # make an empty file
        open("deps.f", 'w').close()