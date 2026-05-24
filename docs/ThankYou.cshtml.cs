using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using PollPoll.Data;
using PollPoll.Models;
using PollPoll.Services;

namespace PollPoll.Pages;

/// <summary>
/// Page model for thank you page after voting
/// GET /thankyou?pollCode={code} - Display thank you message
/// </summary>
public class ThankYouModel : PageModel
{
    private readonly PollDbContext _context;
    private readonly VoteService _voteService;

    public ThankYouModel(PollDbContext context, VoteService voteService)
    {
        _context = context;
        _voteService = voteService;
    }

    public Poll? Poll { get; set; }
    public PollGroup? PollGroup { get; set; }
    public bool IsPartOfGroup { get; set; }
    public int TotalAnswered { get; set; }
    public int TotalInGroup { get; set; }

    public async Task<IActionResult> OnGetAsync(string pollCode)
    {
        if (string.IsNullOrEmpty(pollCode))
        {
            return RedirectToPage("/Index");
        }

        // Load poll with options and poll group
        Poll = await _context.Polls
            .Include(p => p.PollGroup)
            .ThenInclude(pg => pg!.Polls)
            .FirstOrDefaultAsync(p => p.Code == pollCode.ToUpper());

        if (Poll == null)
        {
            return RedirectToPage("/Index");
        }

        // Check if this poll is part of a group
        if (Poll.PollGroupId.HasValue && Poll.PollGroup != null)
        {
            IsPartOfGroup = true;
            PollGroup = Poll.PollGroup;
            
            // Calculate progress
            var pollsInGroup = PollGroup.Polls.OrderBy(p => p.DisplayOrder).ToList();
            TotalInGroup = pollsInGroup.Count;
            
            // Get voter ID and check which polls they've answered
            var voterId = _voteService.GetOrCreateVoterId();
            var pollIds = pollsInGroup.Select(p => p.Id).ToList();
            var answeredPollIds = await _context.Votes
                .Where(v => v.VoterId == voterId && pollIds.Contains(v.PollId))
                .Select(v => v.PollId)
                .Distinct()
                .ToListAsync();
            
            TotalAnswered = answeredPollIds.Count;
        }

        return Page();
    }
}
