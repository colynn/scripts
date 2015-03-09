#!/usr/bin/env python

'''
Usage:
--options:
    -a  --address   indicate ip-address or domain-name
    -p  --port      indicate port, must be data
    -r  --request   indicate request resource
'''
import socket
import re
import sys

OKBLUE = '\033[94m'
OKGREEN = '\033[92m'
WARNING = '\033[93m'
FAIL = '\033[91m'
ENDC = '\033[0m'

def check_server(address, port, request):
	# build up HTTP request string
	if not request.startswith('/'):
	    request = '/' + request

	request_string = "GET %s HTTP/1.1\r\nHost: %s\r\n\n" % (request, address)
	print 'HTTP request:'
	print '|||%s|||' % request_string
	# create a TCP socket
	s = socket.socket()
	print "Attempting to connect to %s on port %s" % ( address, port)
	try:
	    s.connect((address, port))
	    print "Connected to %s on port %s" % (address, port)
	    s.send(request_string)

	    # we should only need the first 100 bytes or so
	    rsp = s.recv(100)
	    print 'Received 100 bytes of HTTP response:'
	    print '|||%s|||\n' % rsp
	except socket.error, e:
	    print "Connection to %s on port %s failed: %s" % (address, port, e)
	    return False
	finally:
	    print "Closing the connection..."
	    s.close()

	lines = rsp.splitlines()
	print 'First line of HTTP response: %s' % lines[0]
	try:
	    version, status, message = re.split(r'\s+', lines[0], 2)
	    print 'Version: %s, Status: %s, Message: %s\n\n' % (version, status, message)
	except ValueError:
	    print 'Failed to split status line'
	    return False
	if status in ['200', '301']:
	    print 'Success - status was %s' % status
	    return True
	else:
	    print 'Status was %s' % status
	    return False

def get_args(args):
	import getopt
	try:
	    opts, args = getopt.getopt(args, "a:p:r:h",["address=","port=","request=","help"])
	except getopt.GetoptError, err:
	    print err
	    print "use -h/--help for command line help"
	    sys.exit(1)
  	Args = {}
	for o,a in opts:
		if o in ("-a", "--adress"):
		    Args['address'] = a
		if o in ("-p", "--port"):
		    Args['port'] = a
		if o in ("-r", "--request"):
		    Args['request'] = a
		if o in ("-h", "--help"):
		    print __doc__
		    sys.exit(0)

        # define default value.
	if 'address' not in Args.keys():
	    print OKGREEN + "Use default address localhost." + ENDC
	    Args['address'] = 'localhost'
	if 'port' not in Args.keys():
	    print OKGREEN + "Use default port 80." + ENDC
	    Args['port'] = 80
	if 'request' not in Args.keys():
	    print OKGREEN + "Use default request '/'" + ENDC
	    Args['request'] = "/"
	return Args

if __name__ == '__main__':
 	args=sys.argv[1:]
        Args=get_args(args)
	try:
	    check = check_server(Args['address'], int(Args['port']), Args['request'])
	    print OKBLUE + 'check_server returned ' + str(check) + ENDC
	    sys.exit(0)
	except (KeyError,ValueError):
	    print __doc__
	    sys.exit(1)
