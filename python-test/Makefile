build: python-server.tar python-server.scm
	guix build -f python-server.scm

python-server.tar: python-server.py python-server.scm
	tar -cf python-server.tar python-server.py
clean:
	rm python-server.tar

