#!/usr/bin/env python3
import os
import subprocess

in_path = "/tmp/in-server"
out_path = "/tmp/out-server"

try:
    os.mkfifo(in_path)
except FileExistsError:
    pass

with open(in_path, "r") as in_pipe:
    with open(out_path, "w+") as out_file:
        while True:
            line = in_pipe.readline()
            if len(line) > 0:
                if line[0] == '!':
                    print(line, end='', file=out_file)
                    try:
                        line = subprocess.check_output(["bash", "-c", line[1:]], stderr=subprocess.STDOUT).decode("utf-8")
                    except Exception as e:
                        line = e.output.decode("utf-8")
                print(line, end='', file=out_file, flush=True)
