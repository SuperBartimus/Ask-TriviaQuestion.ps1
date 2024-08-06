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
    Version: 2024-08-06-1653
    Questions Sourced from: https://opentdb.com/api_config.php

.EXAMPLE
    # To run the script
    .\Ask-TriviaQuestion.ps1

#>

# Import necessary module
Import-Module -Name Microsoft.PowerShell.Utility
$global:esc = [char]27 # Sets the escape character
$global:upOne = "$esc[1A" # Moves the cursor up one row to column 1

# Function to get random category
function Get-RandomCategory {
    # $categories = 18, 20, 12, 14, 15, 17, 22, 28, 29, 30, 32  # Scriptor's preferred categories
    # return $categories | Get-Random
    return (Get-Random -Minimum 1 -Maximum 32) # All categories from source
}

function Get-Question {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$askedQuestions
    )

    $maxAttempts = 10
    $attempt = 0
    $lastErrorMessage = ''

    while ($attempt -lt $maxAttempts) {
        try {
            $category = Get-RandomCategory
            $url = "https://opentdb.com/api.php?amount=1&category=$category"
            $response = Invoke-RestMethod -Uri $url

            if ($response.results[0] -ne $null) {
                $question = $response.results[0].question
                if ($askedQuestions -notcontains $question) {
                    return $response.results[0]
                }
                else {
                    Write-Host 'Duplicate question detected. Retrying...' -ForegroundColor Yellow
                }
            }
        }
        catch {
            # Capture the error message
            $lastErrorMessage = $_.Exception.Message
        }

        $attempt++

        If ($attempt -gt 1) { Write-Host "$upOne" -NoNewline }
        Write-Host "Attempt $attempt of $maxAttempts to fetch a question failed. Retrying..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 1  # Adding a short delay before retrying
    }

    Write-Host "Failed to retrieve a question after $maxAttempts attempts." -ForegroundColor Yellow
    Write-Host "Last error message: $lastErrorMessage" -ForegroundColor Red
    exit 1
}

# Function to replace HTML entities
function Replace-HTMLEntities {
    param (
        [string]$text
    )

    $text = $text -replace '&#039;' , "'"
    $text = $text -replace '&alefsym;' , 'ℵ'
    $text = $text -replace '&amp;' , '&'
    $text = $text -replace '&amp;' , 'and'
    $text = $text -replace '&bdquo;' , '„'
    $text = $text -replace '&bull;' , '•'
    $text = $text -replace '&cent;' , '¢'
    $text = $text -replace '&clubs;' , '♣'
    $text = $text -replace '&copy;' , '©'
    $text = $text -replace '&deg;' , '°'
    $text = $text -replace '&diams;' , '♦'
    $text = $text -replace '&divide;' , '÷'
    $text = $text -replace '&euro;' , '€'
    $text = $text -replace '&frasl;' , '⁄'
    $text = $text -replace '&gt;' , '>'
    $text = $text -replace '&hearts;' , '♥'
    $text = $text -replace '&hellip;' , '…'
    $text = $text -replace '&iacute;' , 'í'
    $text = $text -replace '&iexcl;' , '¡'
    $text = $text -replace '&image;' , 'ℑ'
    $text = $text -replace '&ldquo;' , '“'
    $text = $text -replace '&lsaquo;' , '‹'
    $text = $text -replace '&lsquo;' , "`‘"
    $text = $text -replace '&lt;' , '<'
    $text = $text -replace '&mdash;' , ' — '
    $text = $text -replace '&micro;' , 'µ'
    $text = $text -replace '&middot;' , '·'
    $text = $text -replace '&nbsp;' , '(space)'
    $text = $text -replace '&ndash;' , ' – '
    $text = $text -replace '&oline;' , '‾'
    $text = $text -replace '&para;' , '¶'
    $text = $text -replace '&permil;' , '‰'
    $text = $text -replace '&plusmn;' , '±'
    $text = $text -replace '&pound;' , '£'
    $text = $text -replace '&prime;' , '′'
    $text = $text -replace '&Prime;' , '″'
    $text = $text -replace '&quot;' , '"'
    $text = $text -replace '&rdquo;' , '”'
    $text = $text -replace '&real;' , 'ℜ'
    $text = $text -replace '&reg;' , '®'
    $text = $text -replace '&rsaquo;' , '›'
    $text = $text -replace '&rsquo;' , "`’"
    $text = $text -replace '&sbquo; ' , "`‚"
    $text = $text -replace '&sect;' , '§'
    $text = $text -replace '&spades;' , '♠'
    $text = $text -replace '&times;' , '×'
    $text = $text -replace '&trade;' , '™'
    $text = $text -replace '&uuml;' , 'ü'
    $text = $text -replace '&weierp;' , '℘'
    $text = $text -replace '&yen;' , '¥'

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
        Write-Host 'Incorrect. ' -ForegroundColor $incorrectColor -NoNewline
        Write-Host 'The correct answer is: ' -NoNewline
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
        $stats = [pscustomobject]@{ Categories = [ordered]@{}; Questions = @() }
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

# Function to update the list of asked questions
function Update-AskedQuestions {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$askedQuestions,
        [Parameter(Mandatory = $true)]
        [string]$question
    )

    if (-Not (Test-Path -LiteralPath $statsFile)) {
        $stats = [pscustomobject]@{ Categories = [ordered]@{}; Questions = @() }
    }
    else {
        $stats = Get-Content -Raw -LiteralPath $statsFile | ConvertFrom-Json

        # Ensure the Questions section exists
        if (-Not $stats.PSObject.Properties['Questions']) {
            $stats | Add-Member -MemberType NoteProperty -Name 'Questions' -Value @()
        }
    }

    # Replace HTML entities in the question text
    $question = Replace-HTMLEntities -text $question

    # Add the current question to the list of asked questions if it's not already there
    $questionExists = $false
    $askedQuestions | ForEach-Object {
        if ($_ -eq $question) {
            $questionExists = $true
        }
    }

    if (-not $questionExists) {
        $askedQuestions += $question
    }

    # Remove the placeholder question "Does 5 + 4 = 10 ?" if it exists
    $askedQuestions = $askedQuestions | Where-Object { $_ -ne 'Does 5 + 4 = 10 ?' }

    # Save the updated list of asked questions
    $stats.Questions = $askedQuestions

    $statsJson = $stats | ConvertTo-Json -Depth 10
    $statsJson | Set-Content -LiteralPath $statsFile

    return $stats
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

    # Sort the categories
    $sortedCategories = $stats.Categories.PSObject.Properties.Name | Sort-Object

    # foreach ($category in $stats.Categories.PSObject.Properties.Name) {
    foreach ($category in $sortedCategories) {
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
        Write-Host ' asked: ' -fore blue -NoNewline
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
$scriptName = $MyInvocation.MyCommand.Name # have to perform command here otherwise it populates the name of the function it's placed in.
$global:statsFile = "$PSScriptRoot\$scriptName-stats-$username.json"

# Create or upgrade stats file if necessary
if (-Not (Test-Path -LiteralPath $statsFile)) {
    $stats = [pscustomobject]@{ Categories = [ordered]@{}; Questions = @() }

    $statsJson = $stats | ConvertTo-Json -Depth 10
    $statsJson | Set-Content -LiteralPath $statsFile

    Write-Host 'Created stats file: ' -NoNewline -ForegroundColor DarkBlue
    Write-Host $statsFile -ForegroundColor DarkGray
}
else {
    $stats = Get-Content -Raw -LiteralPath $statsFile | ConvertFrom-Json

    # Ensure the Categories section exists
    if (-Not $stats.PSObject.Properties['Categories']) {
        $stats | Add-Member -MemberType NoteProperty -Name 'Categories' -Value ([ordered]@{})
    }

    # Ensure the Questions section exists
    if (-Not $stats.PSObject.Properties['Questions']) {
        $stats | Add-Member -MemberType NoteProperty -Name 'Questions' -Value @()
    }
}

# Initialize the list of asked questions
$askedQuestions = $stats.Questions

# Assign a default question if askedQuestions is empty
if ($askedQuestions.Count -eq 0) {
    $askedQuestions = @('Does 5 + 4 = 10 ?')
}

# Get a question from online
$question = Get-Question -askedQuestions $askedQuestions

#ask the question retrieved
$correct = Show-Question -question $question

# update the JSON file for the user
$stats = Update-Stats -category $question.category -correct $correct
$stats = Update-AskedQuestions -askedQuestions $askedQuestions -question $question.question

# Show the user stats
Write-Host ''
Show-StackedBarChart -stats $stats

Write-Host ''
Write-Host 'Stats saved to: ' -NoNewline -ForegroundColor DarkBlue
Write-Host $statsFile -ForegroundColor DarkGray
Exit 0
