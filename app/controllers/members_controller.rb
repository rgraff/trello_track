class MembersController < ApplicationController
  def show
    @current_member = trello_client.find(:member, params[:id])

    if request.xhr?
      render js: js_html("#tab_content", partial: "tab")
    else
      @tab_members = []
      @followers = system_user.followers

      @followers.each do |member_id|
        @tab_members << trello_client.find(:member, member_id)
      end

      @tab_members.sort_by!(&:full_name)
    end
  end

  def activities
    @current_member = trello_client.find(:member, params[:id])
    @members = {}

    @actions = @current_member.actions since: Date.yesterday.to_json, limit: 1000

    threads = []
    for action in @actions
      # if idMember exists there is member hash
      # if idMemberAdded exists there isn't member hash so we must get it
      member_id = action.data["idMemberAdded"]
      next if member_id.nil?

      unless @members.has_key?(member_id)
        @members[member_id] = nil
        threads << Thread.new(member_id) do |fetch_id|
          @members[fetch_id] = trello_client.find(:member, fetch_id)
        end
      end
    end
    threads.each {|thr| thr.join }

    render js: js_html("#recent_activity", partial: "activity")
  end

  def cards
    @current_member = trello_client.find(:member, params[:id])
    @cards = @current_member.cards members: true
    @cards.sort_by!(&:last_activity_date).reverse!
    @card_boards = {}
    @card_lists = {}

    threads = []
    for card in @cards
      unless @card_boards.has_key?(card.board_id)
        @card_boards[card.board_id] = nil
        threads << Thread.new(card) do |card_to_fetch|
          @card_boards[card_to_fetch.board_id] = card_to_fetch.board
        end
      end
      unless @card_lists.has_key?(card.list_id)
        @card_lists[card.list_id] = nil
        threads << Thread.new(card) do |card_to_fetch|
          @card_lists[card_to_fetch.list_id] = card_to_fetch.list
        end
      end
    end
    threads.each {|thr| thr.join }

    render js: js_html("#active_cards", partial: "cards")
  end

  def follow
    if params[:follow].blank?
      system_user.followers = system_user.followers - [params[:id]]
    else
      system_user.followers = system_user.followers + [params[:id]]
    end

    render nothing: true
  end
end
