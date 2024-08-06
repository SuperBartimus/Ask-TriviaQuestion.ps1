# Requires PowerShell 5.1 or later
<#
.SYNOPSIS
    PowerShell script to fetch and display trivia questions from Open Trivia Database.

.DESCRIPTION
    This script fetches trivia questions from the Open Trivia Database (https://opentdb.com/api_config.php),
    asks the user to answer, and keeps track of the correct and incorrect answers.
    The results are stored in a JSON file and displayed in a stacked bar chart format.

.NOTES
    Author: Bart Strauss / Completely Computing
    Version: 1.0
    Questions Sourced from: https://opentdb.com/api_config.php

.EXAMPLE
    # To run the script
    .\Ask-TriviaQuestion.ps1

#>

# Import necessary module
Import-Module -Name Microsoft.PowerShell.Utility

# Function to get random category
function Get-RandomCategory {
    # $categories = 18, 20, 12, 14, 15, 17, 22, 28, 29, 30, 32  # Scriptor's preferred categories
    # return $categories | Get-Random
    return (Get-Random -Minimum 1 -Maximum 32) # All categories from source
}

# Function to get question from OpenTDB
function Get-Question {
    $category = Get-RandomCategory
    $url = "https://opentdb.com/api.php?amount=1&category=$category"
    $response = Invoke-RestMethod -Uri $url
    return $response.results[0]
}

# Function to replace HTML entities
function Replace-HTMLEntities {
    param (
        [string]$text
    )
    $text = $text -replace '&quot;', '"'
    $text = $text -replace '&#039;', "'"
    $text = $text -replace '&amp;', 'and'
    $text = $text -replace '&lt;', '<'
    $text = $text -replace '&gt;', '>'
    return $text
}

# Function to sanitize category names for JSON keys
function Sanitize-CategoryName {
    param (
        [string]$category
    )

    $category = Replace-HTMLEntities -text $category
    # $category = $category -replace '[^a-zA-Z0-9]', '_'
    $category = $category -replace '[^a-zA-Z0-9 :]', '_'
    return $category
}

# Function to display question and get answer
function Show-Question {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$question
    )

    # Set color variables
    $questionColor = 'Blue'
    $answerColor = 'Cyan'
    $correctColor = 'Green'
    $incorrectColor = 'yellow'

    # Replace HTML entities in the question and category
    $questionText = Replace-HTMLEntities -text $question.question
    $categoryText = Replace-HTMLEntities -text $question.category

    Write-Host 'Category: ' -ForegroundColor $questionColor -NoNewline
    Write-Host "$categoryText`t" -NoNewline
    Write-Host 'Difficulty: ' -ForegroundColor $questionColor -NoNewline
    Write-Host "$($question.difficulty)"
    Write-Host 'Question: ' -ForegroundColor $questionColor -NoNewline
    Write-Host "$questionText`n"

    if ($question.type -eq 'boolean') {
        Write-Host "Please answer with 'T' or 'F' for True or False" -ForegroundColor $answerColor
        $userAnswer = Read-Host
        if ($userAnswer -eq 'T') { $userAnswer = 'True' }
        elseif ($userAnswer -eq 'F') { $userAnswer = 'False' }
    }
    elseif ($question.type -eq 'multiple') {
        $options = $question.incorrect_answers + $question.correct_answer
        $options = $options | Sort-Object { Get-Random }
        $letters = 'A', 'B', 'C', 'D'
        Write-Host 'Options:' -ForegroundColor $answerColor
        $options | ForEach-Object -Begin { $index = 0 } -Process {
            Write-Host "$($letters[$index]). $(Replace-HTMLEntities -text $_)" -ForegroundColor $answerColor
            $index++
        }
        $userAnswerLetter = Read-Host
        $userAnswer = $options[$letters.IndexOf($userAnswerLetter.ToUpper())]
    }

    if ($userAnswer -eq $question.correct_answer) {
        Write-Host 'Correct!' -ForegroundColor $correctColor
        return $true
    }
    else {
        Write-Host "Incorrect. " -ForegroundColor $incorrectColor -NoNewline
        Write-Host "The correct answer is: " -NoNewline
        Write-Host $(Replace-HTMLEntities -text $question.correct_answer) -ForegroundColor $correctColor
        return $false
    }
}

# Function to update stats
function Update-Stats {
    param (
        [Parameter(Mandatory = $true)]
        [string]$category,
        [Parameter(Mandatory = $true)]
        [bool]$correct
    )

    # Sanitize category name for JSON key
    $sanitizedCategory = Sanitize-CategoryName -category $category

    if (-Not (Test-Path -LiteralPath $statsFile)) {
        $stats = [pscustomobject]@{ Categories = [ordered]@{} }
    }
    else {
        $stats = Get-Content -Raw -LiteralPath $statsFile | ConvertFrom-Json
    }

    if (-Not $stats.Categories.PSObject.Properties[$sanitizedCategory]) {
        $categoryStats = [pscustomobject]@{
            Correct   = 0
            Incorrect = 0
        }
        $stats.Categories | Add-Member -MemberType NoteProperty -Name $sanitizedCategory -Value $categoryStats
    }

    if ($correct) {
        $stats.Categories.$sanitizedCategory.Correct++
    }
    else {
        $stats.Categories.$sanitizedCategory.Incorrect++
    }

    $statsJson = $stats | ConvertTo-Json -Depth 10
    $statsJson | Set-Content -LiteralPath $statsFile

    return $stats
}

# Function to display stats
function Show-Stats {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$stats
    )

    $totalCorrect = 0
    $totalQuestions = 0

    Write-Host 'Category Stats:' -ForegroundColor 'Yellow'

    foreach ($category in $stats.Categories.PSObject.Properties.Name) {
        $correct = $stats.Categories.$category.Correct
        $incorrect = $stats.Categories.$category.Incorrect
        $totalCorrect += $correct
        $totalQuestions += ($correct + $incorrect)
        $categoryAccuracy = if ($correct + $incorrect -eq 0) { 0 } else { [math]::Round(($correct / ($correct + $incorrect)) * 100, 2) }
        Write-Host "${category}: ${correct} correct, ${incorrect} incorrect, Accuracy: ${categoryAccuracy}%" -ForegroundColor 'Cyan'
    }

    $overallAccuracy = if ($totalQuestions -eq 0) { 0 } else { [math]::Round(($totalCorrect / $totalQuestions) * 100, 2) }
    Write-Host "Overall Accuracy: ${overallAccuracy}%" -ForegroundColor 'Cyan'
}


# Function to display stacked bar charts
function Show-StackedBarChart {
    param (
        [Parameter(Mandatory = $true)]
        [pscustomobject]$stats
    )

    Write-Host 'Category Accuracy Stacked Bar Charts:' -ForegroundColor 'Yellow'

    # Determine the maximum length of category names
    $maxCategoryLength = ($stats.Categories.PSObject.Properties.Name | Measure-Object -Maximum Length).Maximum

    foreach ($category in $stats.Categories.PSObject.Properties.Name) {
        $correct = $stats.Categories.$category.Correct
        $incorrect = $stats.Categories.$category.Incorrect
        $total = $correct + $incorrect
        if ($total -eq 0) { continue }

        $totalCorrect += $correct
        $totalIncorrect += $incorrect

        $correctPercentage = [math]::Round(($correct / $total) * 100)
        $incorrectPercentage = 100 - $correctPercentage

        # Create bar chart using ASCII characters
        $correctBars = ('#' * ($correctPercentage / 2))
        $incorrectBars = ('@' * ($incorrectPercentage / 2))

        $correctPercentagestr = $correctPercentage.ToString('000')
        $incorrectPercentagestr = $incorrectPercentage.ToString('000')

        # Pad category name to align the bars
        $paddedCategory = $category.PadRight($maxCategoryLength + 2)

        Write-Host "$($paddedCategory): " -NoNewline
        Write-Host ' asked: ' -fore blue -NoNewline
        Write-Host "$($total.toString('0000'))   " -fore gray -NoNewline
        Write-Host ': ' -ForegroundColor White -NoNewline
        Write-Host "$correctPercentagestr% Correct " -ForegroundColor cyan -NoNewline
        Write-Host $correctBars -ForegroundColor Green -NoNewline
        Write-Host $incorrectBars -ForegroundColor Yellow -NoNewline
        Write-Host " $incorrectPercentagestr% Incorrect" -ForegroundColor cyan
    }

    # Overall total bar
    $total = $totalCorrect + $totalIncorrect
    if ($total -ne 0) {
        $overallCorrectPercentage = [math]::Round(($totalCorrect / $total) * 100)
        $overallIncorrectPercentage = 100 - $overallCorrectPercentage

        # Convert overall percentages to strings with leading zeros
        $overallCorrectPercentageStr = $overallCorrectPercentage.ToString('000')
        $overallIncorrectPercentageStr = $overallIncorrectPercentage.ToString('000')

        $overallCorrectBars = ('#' * ($overallCorrectPercentage / 2))
        $overallIncorrectBars = ('@' * ($overallIncorrectPercentage / 2))

        Write-Host "`nOverall Total".PadRight($maxCategoryLength + 3) -ForegroundColor White -NoNewline
        Write-Host ': ' -ForegroundColor White -NoNewline
        Write-Host " asked: " -fore blue -NoNewline
        Write-Host "$($total.toString('0000'))   " -fore gray -NoNewline
        Write-Host ': ' -ForegroundColor White -NoNewline
        Write-Host "$overallCorrectPercentageStr% Correct " -ForegroundColor cyan -NoNewline
        Write-Host $overallCorrectBars -ForegroundColor Green -NoNewline
        Write-Host $overallIncorrectBars -ForegroundColor Yellow -NoNewline
        Write-Host " $overallIncorrectPercentageStr% Incorrect" -ForegroundColor cyan
    }
}

# Main script logic
$username = $env:USERNAME
$scriptName = $MyInvocation.MyCommand.Name # have to perform command her otherwise it populates the name of the function its placed in.
$global:statsFile = "$PSScriptRoot\$scriptName-stats-$username.json"

# Create stats file if it doesn't exist.  Necessary here because showing stats for non-existent file creates 'division by zero' errors
if (-Not (Test-Path -LiteralPath $statsFile)) {
    $stats = [pscustomobject]@{ Categories = [ordered]@{} }

    $statsJson = $stats | ConvertTo-Json -Depth 10
    $statsJson | Set-Content -LiteralPath $statsFile

    Write-Host 'Created stats file: ' -NoNewline -fore DarkBlue
    Write-Host $statsFile -ForegroundColor darkgray
}

$question = Get-Question
$correct = Show-Question -question $question
$stats = Update-Stats -category $question.category -correct $correct

Write-Host ''
# Show-Stats -stats $stats  # removed this function call as the barchart function is nicer.  Left code for 'just in case'
Show-StackedBarChart -stats $stats

Write-Host ''
Write-Host 'Stats saved to: ' -NoNewline -fore DarkBlue
Write-Host $statsFile -ForegroundColor darkgray