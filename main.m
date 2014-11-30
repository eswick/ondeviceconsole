#import <sys/socket.h>
#import <sys/un.h>

#import <unistd.h>
#import <fcntl.h>
#import <poll.h>

#define SOCKET_PATH "/var/run/lockdown/syslog.sock"

#define COLOR_RESET         "\e[m"
#define COLOR_NORMAL        "\e[0m"
#define COLOR_DARK          "\e[2m"
#define COLOR_RED           "\e[0;31m"
#define COLOR_DARK_RED      "\e[2;31m"
#define COLOR_GREEN         "\e[0;32m"
#define COLOR_DARK_GREEN    "\e[2;32m"
#define COLOR_YELLOW        "\e[0;33m"
#define COLOR_DARK_YELLOW   "\e[2;33m"
#define COLOR_BLUE          "\e[0;34m"
#define COLOR_DARK_BLUE     "\e[2;34m"
#define COLOR_MAGENTA       "\e[0;35m"
#define COLOR_DARK_MAGENTA  "\e[2;35m"
#define COLOR_CYAN          "\e[0;36m"
#define COLOR_DARK_CYAN     "\e[2;36m"
#define COLOR_WHITE         "\e[0;37m"
#define COLOR_DARK_WHITE    "\e[0;37m"



size_t atomicio(ssize_t (*f) (int, void *, size_t), int fd, void *_s, size_t n)
{
	char *s = _s;
	size_t pos = 0;
	ssize_t res;
	struct pollfd pfd;

	pfd.fd = fd;
	pfd.events = f == read ? POLLIN : POLLOUT;
	while (n > pos) {
		res = (f) (fd, s + pos, n - pos);
		switch (res) {
		case -1:
			if (errno == EINTR)
				continue;
			if ((errno == EAGAIN) || (errno == ENOBUFS)) {
				(void)poll(&pfd, 1, -1);
				continue;
			}
			return 0;
		case 0:
			errno = EPIPE;
			return pos;
		default:
			pos += (size_t)res;
		}
	}
	return (pos);
}

int unix_connect(char* path){
	struct sockaddr_un sun;
	int s;

	if ((s = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
		return (-1);
	(void)fcntl(s, F_SETFD, 1);

	memset(&sun, 0, sizeof(struct sockaddr_un));
	sun.sun_family = AF_UNIX;

	if (strlcpy(sun.sun_path, path, sizeof(sun.sun_path)) >= sizeof(sun.sun_path)) {
		close(s);
		errno = ENAMETOOLONG;
		return (-1);
	}
	if (connect(s, (struct sockaddr *)&sun, SUN_LEN(&sun)) < 0) {
		close(s);
		return (-1);
	}

	return (s);
}

#define LINE_REGEX "(\\w+\\s+\\d+\\s+\\d+:\\d+:\\d+)\\s+(\\S+|)\\s+(\\w+)\\[(\\d+)\\]\\s+\\<(\\w+)\\>:\\s(.*)"

ssize_t write_colored(int fd, void* buffer, size_t len){

	char *escapedBuffer = malloc(len + 1);
	memcpy(escapedBuffer, buffer, len);
	escapedBuffer[len] = '\0';

	NSString *str = [NSString stringWithUTF8String:escapedBuffer];
	free(escapedBuffer);

	NSError *error = nil;
	NSRegularExpression *regex = [NSRegularExpression
																	regularExpressionWithPattern:@LINE_REGEX
																	options:NSRegularExpressionCaseInsensitive
																	error:&error];

	NSArray *matches = [regex matchesInString:str
														options:0
														range:NSMakeRange(0, [str length])];

	if([matches count] == 0)
		return write(fd, buffer, len);

	for (NSTextCheckingResult *match in matches) {

		if([match numberOfRanges] < 6) {
			write(fd, buffer, len); // if entry doesn't match regex, print uncolored
			continue;
		}

		NSRange dateRange 	 =  [match rangeAtIndex:1];
		NSRange deviceRange  =  [match rangeAtIndex:2];
		NSRange processRange =  [match rangeAtIndex:3];
		NSRange pidRange 		 =  [match rangeAtIndex:4];
		NSRange typeRange 	 =  [match rangeAtIndex:5];
		NSRange logRange		 =  [match rangeAtIndex:6];

		NSString *date 			 =  [str substringWithRange:dateRange];
		NSString *device 		 =  [str substringWithRange:deviceRange];
		NSString *process 	 =  [str substringWithRange:processRange];
		NSString *pid 			 =  [str substringWithRange:pidRange];
		NSString *type 			 =  [str substringWithRange:typeRange];
		NSString *log 			 = 	[str substringWithRange:
																 NSMakeRange(logRange.location,
																 						 [str length] - logRange.location)];

		log = [log stringByTrimmingCharactersInSet:
								[NSCharacterSet newlineCharacterSet]];

		NSMutableString *build = [NSMutableString new];

		[build appendString:@COLOR_DARK_WHITE];
		[build appendString:date];
		[build appendString:@" "];
		[build appendString:device];
		[build appendString:@" "];

		[build appendString:@COLOR_CYAN];
		[build appendString:process];
		[build appendString:@"["];
		[build appendString:pid];
		[build appendString:@"]"];

		char *typeColor = COLOR_DARK_WHITE;
		char *darkTypeColor = COLOR_DARK_WHITE;

		if ([type isEqualToString:@"Notice"]) {
			typeColor = COLOR_GREEN;
			darkTypeColor = COLOR_DARK_GREEN;
		} else if ([type isEqualToString:@"Warning"]) {
			typeColor = COLOR_YELLOW;
			darkTypeColor = COLOR_DARK_YELLOW;
		} else if ([type isEqualToString:@"Error"]) {
			typeColor = COLOR_RED;
			darkTypeColor = COLOR_DARK_RED;
		} else if ([type isEqualToString:@"Debug"]) {
			typeColor = COLOR_MAGENTA;
			darkTypeColor = COLOR_DARK_MAGENTA;
		}

		[build appendString:@(darkTypeColor)];
		[build appendString:@" <"];
		[build appendString:@(typeColor)];
		[build appendString:type];
		[build appendString:@(darkTypeColor)];
		[build appendString:@">"];
		[build appendString:@COLOR_RESET];
		[build appendString:@": "];
		[build appendString:log];

		printf("%s\n", [build UTF8String]);
		[build release];
	}

	return len;
}

int main(int argc, char **argv, char **envp) {

	int nfd = unix_connect(SOCKET_PATH);

	// write "watch" command to socket to begin receiving messages
	write(nfd, "watch\n", 6);

	struct pollfd pfd[2];
	unsigned char buf[16384];
	int n = fileno(stdin);
	int lfd = fileno(stdout);
	int plen = 16384;

	pfd[0].fd = nfd;
	pfd[0].events = POLLIN;

	while (pfd[0].fd != -1) {

		if ((n = poll(pfd, 1, -1)) < 0) {
			close(nfd);
			perror("polling error");
			exit(1);
		}

		if (pfd[0].revents & POLLIN) {
			if ((n = read(nfd, buf, plen)) < 0)
				perror("read error"), exit(1); /* possibly not an error, just disconnection */
			else if (n == 0) {
				shutdown(nfd, SHUT_RD);
				pfd[0].fd = -1;
				pfd[0].events = 0;
			} else {
				if (atomicio(write_colored, lfd, buf, n) != n)
					perror("atomicio failure"), exit(1);
			}
		}
	}

	return 0;
}
