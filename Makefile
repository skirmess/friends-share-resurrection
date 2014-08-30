
.PHONY: clean release

VERSION=25

clean:
	find . -name '*~' -print -delete

release: clean
	git branch $(VERSION)
	git checkout $(VERSION)
	rm -f FriendsShare-$(VERSION).zip
	find FriendsShare				\
		-name .git -prune -o			\
		-name Makefile -prune -o		\
		-name '.*.swp' -prune -o		\
		-print > files.txt
	zip -@ FriendsShare-$(VERSION).zip < files.txt
	rm -f files.txt
	git add FriendsShare-$(VERSION).zip
	git commit -m $(VERSION) FriendsShare-$(VERSION).zip
	git tag -a $(VERSION)
	git checkout master
	git branch -D $(VERSION)
	@echo
	@echo "Now push the new tag with"
	@echo "git push --tags"
	@echo
