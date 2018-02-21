## How to add new topics or materials

#### Steps

![Content screenshot](CONTENTSCREENSHOT.png)

2. Go to `Roadmap Project/Script`
3. Open `Content.yml`, add topics or links to materials
4. Run `main.swift`
5. Commit and push all generated files and changes
6. Submit a pull request

Note. I've used Sublime text for editing YAML.

#### Prerequisites

1. Git
1. Latest Swift/xCode
1. Fork of the repository
1. Prepare PlantUML:
	1. Install [JDK](http://www.oracle.com/technetwork/java/javase/downloads/jdk9-downloads-3848520.html)
	1. Install Homebrew:
		- `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
	1. Install GraphViz:
		- `brew install libtool`
		- `brew link libtool`
		- `brew install graphviz`
		- `brew link --overwrite graphviz`
	1. Go to `Roadmap Project/Script/` 
	1. Run `java -jar plantuml.jar -testdot` to check if installed correctly.

#### How to debug script
Use `Roadmap Project/Roadmap.xcodeproj` to run and debug script.

xCode runs and debugs an executable binary, thus generated output will be put next to the binary.

Always run script via terminal before submitting a PR.
