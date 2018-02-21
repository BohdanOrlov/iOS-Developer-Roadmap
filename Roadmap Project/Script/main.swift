#!/usr/bin/env swift -F ../cocoapods-rome/Rome
//
//  main.swift
//  Roadmap
//
//  Created by Bohdan Orlov on 20/02/2018.
//  Copyright © 2018 Bohdan Orlov. All rights reserved.
//

import Foundation
import Yaml


// Domain

struct Resource {
    let name: String
    let urlString: String
}

typealias ResourceType = String
struct ResourceGroup {
    let type: ResourceType
    let resources: [Resource]
}

class Topic {
    let name: String
    let isEssential: Bool
    let resourses: [ResourceGroup]
    private(set) weak var parrent: Topic?
    init(name: String, resourses: [ResourceGroup], parrent: Topic?) {
        self.parrent = parrent
        self.name = name.trimmingCharacters(in: CharacterSet(charactersIn: "^"))
        self.isEssential = name.hasSuffix("^")
        self.resourses = resourses
    }
}

// YAML parsing

func parce(resourses: Yaml) -> [ResourceGroup] {
    let resoursesMap = resourses.dictionary!
    var resourcesByType = [ResourceGroup] ()
    resoursesMap.values.first!.array!.forEach {
        let resourceMap = $0.dictionary!
        let type = resourceMap.keys.first!.string!
        let resources: [Resource] = resourceMap.values.first!.array!.map {
            let resourceMap = $0.dictionary!
            let name = resourceMap.keys.first!.string!
            let urlString = resourceMap.values.first!.string!
            return Resource(name: name, urlString: urlString)
        }
        resourcesByType.append(ResourceGroup(type: type, resources: resources))
    }
    return resourcesByType
}

func parceTopics(from content: Yaml) -> [Topic] {
    var parrents = [Yaml: Topic]()
    var topics = [Topic]()
    var stack:[Yaml] = content.array!
    while let topicEntry = stack.first {
        stack.removeFirst()
        let topicMap = topicEntry.dictionary!
        let topicName = topicMap.keys.first!.string!
        let children = topicMap.values.first?.array ?? []
        var resources = [ResourceGroup]()
        if let resourcesEntry = children.first(where: { $0.dictionary!.keys.first! == "RESOURCES" }) {
            resources = parce(resourses: resourcesEntry)
        }
        let topic = Topic(name: topicName, resourses: resources, parrent: parrents[topicEntry])
        topics.append(topic)
        let subtopics = children.filter { $0.dictionary!.keys.first! != "RESOURCES" }
        subtopics.forEach { parrents[$0] = topic }
        stack.insert(contentsOf: subtopics, at: 0)
    }
    return topics
}

// Markdown Rendering

extension Topic {
    var parrents: [Topic] {
        var parrents = [Topic]()
        var next = self
        while let parrent = next.parrent {
            parrents.append(parrent)
            next = parrent
        }
        return parrents
    }
    
    var parrentsCount: Int {
        return self.parrents.count
    }
    
    var topicsPathComponents: [String] {
        let reversedParents: [Topic] = self.parrents.reversed()
        let pathComponents = (reversedParents + [self]).map { $0.name }
        return pathComponents
    }
    
    var resourcesDirPath: String {
        let resourcesDir = "Resources"
        let path = resourcesDir + "/" + self.topicsPathComponents.joined(separator: "/")
        return path
    }
    
    var resourcesPath: String {
        return resourcesDirPath + "/" + "RESOURCES.md"
    }
}

func generateRoadmapMarkdown(from topics: [Topic]) {
    var roadmapMarkdown = "# iOS Developer Roadmap\n## Text version\nTapping on a link will take you to relevant materials.\n\n"
    for topic in topics {
        var topicName = topic.name
        if topic.isEssential {
            topicName = "`\(topicName)`"
        }
        if !topic.resourses.isEmpty {
            topicName = "[\(topicName)](\(topic.resourcesPath))"
        }
        let identation = String(repeating: "    ", count: topic.parrentsCount)
        roadmapMarkdown.append(identation + "- [ ] " + topicName + "\n")
    }
    try! FileManager.default.createDirectory(atPath: "Generated", withIntermediateDirectories: true, attributes: [:])
    try! roadmapMarkdown.write(toFile: "Generated/ROADMAP.md", atomically: false, encoding: .utf8)
}

func generateResourcesMarkdown(from topics: [Topic]) {
    
    for topic in topics {
        if topic.resourses.isEmpty { continue }
        let pathComponents = topic.topicsPathComponents
        var resourcesMarkdown = "## " + pathComponents.joined(separator: " > ") + "\n\n"
        for resourceGroup in topic.resourses {
            resourcesMarkdown.append("### " + resourceGroup.type + "\n")
            for resource in resourceGroup.resources {
                resourcesMarkdown.append("- [ ] [\(resource.name)](\(resource.urlString))\n")
            }
            resourcesMarkdown.append("\n")
        }
        resourcesMarkdown.append("\n")
        try! FileManager.default.createDirectory(atPath: "Generated" + "/" + topic.resourcesDirPath, withIntermediateDirectories: true, attributes: [:])
        try! resourcesMarkdown.write(toFile: "Generated" + "/" + topic.resourcesPath, atomically: false, encoding: .utf8)
    }
}

// Main

let content = try! String(contentsOfFile: "Content.yml")
let parsedContent = try! Yaml.load(content)
let topics = parceTopics(from: parsedContent)
try? FileManager.default.removeItem(atPath: "Generated")
generateRoadmapMarkdown(from: topics)
generateResourcesMarkdown(from: topics)
print("Done. Check 'Generated' folder for output. Don't forget to check the diff before submitting a PR.")
