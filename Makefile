
.PHONY: clean release

VERSION=25

clean:
	gfind . -name '*~' -print -delete

release: clean
	git branch v$(VERSION)
	git checkout v$(VERSION)
	rm -f FriendsShare-$(VERSION).zip
	find FriendsShare				\
		-name .git -prune -o			\
		-name Makefile -prune -o		\
		-name '.*.swp' -prune -o		\
		-print > files.txt
	zip -@ FriendsShare-$(VERSION).zip < files.txt
	rm -f files.txt
	git add FriendsShare-$(VERSION).zip
	git commit -m v$(VERSION) FriendsShare-$(VERSION).zip
	git tag -a v$(VERSION)
	git checkout master
	git branch -D v$(VERSION)
	@echo
	@echo "Now push the new tag with"
	@echo "git push --tags"
	@echo
