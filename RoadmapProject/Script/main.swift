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
    private(set) weak var superTopic: Topic?
    init(name: String, resourses: [ResourceGroup], superTopic: Topic?) {
        let essentialSuffix = "^"
        self.superTopic = superTopic
        self.resourses = resourses
        self.isEssential = name.hasSuffix(essentialSuffix)
        self.name = name.trimmingCharacters(in: CharacterSet(charactersIn: essentialSuffix))
    }
}

// YAML parsing

func parce(resourses: Yaml) -> [ResourceGroup] {
    let resourseGroupsMap = resourses.dictionary!
    let resourceGroups: [ResourceGroup] = resourseGroupsMap.values.first!.array!.map {
        let resourceGroupMap = $0.dictionary!
        let type = resourceGroupMap.keys.first!.string!
        let resources: [Resource] = resourceGroupMap.values.first!.array!.map {
            let resourceMap = $0.dictionary!
            let name = resourceMap.keys.first!.string!
            let urlString = resourceMap.values.first!.string!
            return Resource(name: name, urlString: urlString)
        }
        return ResourceGroup(type: type, resources: resources)
    }
    return resourceGroups
}

func parce(children: [Yaml]) -> ([ResourceGroup], [Yaml]) {
    let resourcesKeyword = "RESOURCES"
    let resources: [ResourceGroup]
    if let resourcesEntry = children.first(where: { $0.dictionary!.keys.first!.string! ==  resourcesKeyword}) {
        resources = parce(resourses: resourcesEntry)
    } else {
        resources = []
    }
    let subtopicsYaml = children.filter { $0.dictionary!.keys.first!.string! != resourcesKeyword }
    return (resources, subtopicsYaml)
}

func parceTopics(from content: Yaml) -> [Topic] { // Topics parced by non-recursive DFS
    
    var resultTopics = [Topic]()
    var superTopicsByYamlTopic = [Yaml: Topic]()
    var stack: [Yaml] = content.array!
    while let topicYaml = stack.first {
        stack.removeFirst()
        let topicMap = topicYaml.dictionary!
        let topicName = topicMap.keys.first!.string!
        let childrenYaml = topicMap.values.first?.array ?? []
        let (resources, subtopicsYaml) = parce(children: childrenYaml)
        let topic = Topic(name: topicName, resourses: resources, superTopic: superTopicsByYamlTopic[topicYaml])
        resultTopics.append(topic)
        subtopicsYaml.forEach { superTopicsByYamlTopic[$0] = topic }
        stack.insert(contentsOf: subtopicsYaml, at: 0)
    }
    return resultTopics
}

// Markdown Rendering

let generatedDir = "Generated"
let resourcesDir = "Resources"
let roadmapMD = "ROADMAP.md"
let roadmapMDPath = generatedDir + "/" + roadmapMD

extension Topic {
    var superTopics: [Topic] {
        var superTopics = [Topic]()
        var currentTopic = self
        while let superTopic = currentTopic.superTopic {
            superTopics.append(superTopic)
            currentTopic = superTopic
        }
        return superTopics
    }
    
    var superTopicNamesFromRoot: [String] {
        let reversedParents: [Topic] = superTopics.reversed()
        let pathComponents = (reversedParents + [self]).map { $0.name }
        return pathComponents
    }
    
    var resourceDirPathInGeneratedDir: String {
        return resourcesDir + "/" + superTopicNamesFromRoot.joined(separator: "/").replacingOccurrences(of: " ", with: "_")
    }
    
    var resourcesPathInGeneratedDir: String {
        return resourceDirPathInGeneratedDir + "/" + resourcesFileName
    }
    
    var resourcesDirPath: String {
        let path = generatedDir + "/" + resourceDirPathInGeneratedDir
        return path
    }
    
    var resourcesPath: String {
        return resourcesDirPath + "/" + resourcesFileName
    }
    
    var resourcesFileName: String {
        return "RESOURCES.md"
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
            topicName = "[\(topicName)](\(topic.resourcesPathInGeneratedDir))"  // Adding link to resources if any
        }
        let identation = String(repeating: "    ", count: topic.superTopics.count)
        roadmapMarkdown.append(identation + "- [ ] " + topicName + "\n")
    }
    try! FileManager.default.createDirectory(atPath: generatedDir, withIntermediateDirectories: true, attributes: [:])
    try! roadmapMarkdown.write(toFile: roadmapMDPath, atomically: false, encoding: .utf8)
}

func generateResourcesMarkdown(from topics: [Topic]) {
    for topic in topics {
        if topic.resourses.isEmpty { continue }
        let pathComponents = topic.superTopicNamesFromRoot
        var resourcesMarkdown = "## " + pathComponents.joined(separator: " > ") + "\n\n"
        for resourceGroup in topic.resourses {
            resourcesMarkdown.append("### " + resourceGroup.type + "\n")
            for resource in resourceGroup.resources {
                resourcesMarkdown.append("- [ ] [\(resource.name)](\(resource.urlString))\n")
            }
            resourcesMarkdown.append("\n")
        }
        resourcesMarkdown.append("\n")
        try! FileManager.default.createDirectory(atPath: topic.resourcesDirPath, withIntermediateDirectories: true, attributes: [:])
        try! resourcesMarkdown.write(toFile: topic.resourcesPath, atomically: false, encoding: .utf8)
    }
}

// Image generation (PlantUML)

extension Topic: Hashable {
    var hashValue: Int {
        return name.hashValue
    }
    
    static func ==(lhs: Topic, rhs: Topic) -> Bool {
        return lhs === rhs
    }
}

extension Topic {
    var plantUMLName: String {
        return name.sanitizedForPlantUML
    }
    var plantUMLAlias: String {
        return superTopicNamesFromRoot.joined(separator: "->").sanitizedForPlantUML
    }
}

extension String {
    var sanitizedForPlantUML: String {
        var result = self.replacingOccurrences(of: "(", with: "[")
        result = result.replacingOccurrences(of: ")", with: "]")
        return result
    }
}

@discardableResult
func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

func generateImages(from topics: [Topic]) {
    generateImage(from: topics, essentialOnly: true)
    generateImage(from: topics, essentialOnly: false)
}

func usecaseWithAllias(from topic: Topic, skipAddingEssentialMark: Bool) -> String {
    let alias = topic.plantUMLAlias
    var essential = ""
    if !skipAddingEssentialMark && topic.isEssential {
        essential = " <<^>> "
    }
    return "(\(topic.plantUMLName)) as (\(alias))\(essential)\n"
}

func skinparam() -> String {
    let pallete = ["White", "#F5F0F2", "#17468A", "#E12D53", "#17468A"]
    return """
    skinparam Shadowing false
    skinparam Padding 0
    skinparam BackgroundColor \(pallete[0])
    
    skinparam Actor {
        BackgroundColor \(pallete[1])
        BorderColor \(pallete[2])
        FontColor \(pallete[3])
        FontName Helvetica
        FontSize 30
        FontStyle Bold
    }
    
    skinparam Arrow {
        Thickness 3
        Color \(pallete[4])
    }
    
    skinparam usecase {
        BorderThickness 3
        BackgroundColor \(pallete[1])
        BorderColor \(pallete[2])
        FontColor \(pallete[3])
        FontName Helvetica
        FontStyle Bold
        FontSize 20
    }
    """
}

func content(from topics: [Topic], essentialOnly: Bool) -> String {
    var availableArrows = ["-down->", "-up->", "-left->", "-right->"]
    var arrowsByParrent = [Topic: String]()
    var usecasesWithAliases = ""
    var topicRelationships = "You -|> (\(topics.first!.plantUMLAlias))\n"
    for topic in topics {
        if essentialOnly && !topic.isEssential {
            continue
        }
        usecasesWithAliases.append(usecaseWithAllias(from: topic, skipAddingEssentialMark: essentialOnly))
        guard let superTopic = topic.superTopic else {
            continue
        }
        let arrow = arrowsByParrent[superTopic] ?? availableArrows.removeFirst()
        arrowsByParrent[topic] = arrow
        topicRelationships.append("(\(superTopic.plantUMLAlias)) \(arrow) (\(topic.plantUMLAlias))\n")
    }
    let content = usecasesWithAliases + "\n" + topicRelationships
    return content
}

func generateImage(from topics: [Topic], essentialOnly: Bool) {

    let legend = essentialOnly ? "" : """
    legend right
    <<^>> - for essential topics
    endlegend
    """
    
    let plantUMLText = """
    @startuml
    left to right direction
    \(content(from: topics, essentialOnly: essentialOnly))
    \(skinparam())
    \(legend)
    @enduml
    """
    
    let imageName = essentialOnly ? "ESSENTIALROADMAP" : "ROADMAP"
    
    let path = generatedDir + "/" + imageName + ".txt"
    let excistingRoadmapText = try? String(contentsOfFile: path)
    guard plantUMLText != excistingRoadmapText else {
        return
    }
    try! plantUMLText.write(toFile: path, atomically: false, encoding: .utf8)
    shell("java", "-DPLANTUML_LIMIT_SIZE=8192", "-jar", "plantuml.jar", path)
}

// Main

print("Note. This script relies on hope instead of proper error handling. It will explode if you violate implicit expectations from Content.yml. Now pray...")

let content = try! String(contentsOfFile: "Content.yml")
let parsedContent = try! Yaml.load(content)
let topics = parceTopics(from: parsedContent)
try? FileManager.default.removeItem(atPath: generatedDir + "/" + resourcesDir)
generateRoadmapMarkdown(from: topics)
generateResourcesMarkdown(from: topics)
generateImages(from: topics)

print("Done! Check 'Generated' folder for output. Don't forget to check the diff before submitting a PR.")
