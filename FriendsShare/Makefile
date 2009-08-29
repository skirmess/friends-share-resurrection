
.PHONY: clean tag release

VERSION=14

clean:
	rm -f *~

tag: clean
	cvs tag FriendsShare-$(VERSION)

release: clean
	( cd ..;							\
		rm -f FriendsShare-$(VERSION).zip;			\
		find FriendsShare					\
				-name CVS -prune -o			\
				-name .svn -prune -o			\
				-name Makefile -prune -o		\
				-name '.*.swp' -prune -o		\
				-print					\
		| zip -@ FriendsShare-$(VERSION).zip;			\
	)
