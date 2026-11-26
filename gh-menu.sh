#!/bin/bash
# GitHub Interactive Menu - Semua operasi GitHub via gh CLI
# Penulis: Hermes Agent (deku)
# Pakai: ./gh-menu.sh atau bash ~/Github/gh-menu.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

check_auth() {
    echo -e "${BLUE}Memeriksa status autentikasi GitHub...${NC}"
    if gh auth status 2>/dev/null; then
        echo -e "${GREEN}GitHub sudah terautentikasi!${NC}"
        return 0
    else
        echo -e "${RED}Gagal memeriksa autentikasi. Jalankan 'gh auth login' terlebih dahulu.${NC}"
        return 1
    fi
}

get_repo() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        REPO_NAME=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
        if [ -n "$REPO_NAME" ]; then
            echo -e "${GREEN}Menggunakan repo aktif: $REPO_NAME${NC}"
            export REPO_NAME
            return 0
        fi
    fi

    echo -e "${CYAN}Daftar repositori Anda:${NC}"
    gh repo list --limit 30 --json name,owner,visibility -q '.[] | "\(.owner.login)/\(.name) (\(.visibility))"'
    echo ""
    read -p "Masukkan nama repo (owner/repo) atau tekan ENTER untuk batal: " repo_input
    if [ -z "$repo_input" ]; then
        echo -e "${RED}Tidak ada repo yang dipilih.${NC}"
        return 1
    fi
    REPO_NAME="$repo_input"
    export REPO_NAME
    return 0
}

list_repos() {
    echo -e "${BLUE}Mengunduh daftar repositori...${NC}"
    gh repo list --json name,owner,visibility,defaultBranchRef,pushedAt,createdAt,isFork \
        --jq '.[] | "\(.owner.login)/\(.name) | \(.visibility) | \(.defaultBranchRef.name // "N/A") | \(.pushedAt[:10])"' | column -t -s'|'
    echo ""
}

clone_repo() {
    echo -e "${CYAN}Contoh: owner/repo${NC}"
    read -p "Masukkan URL atau nama repo yang ingin clone: " clone_url
    if [ -z "$clone_url" ]; then
        echo -e "${RED}URL/nama repo tidak boleh kosong.${NC}"
        return
    fi
    read -p "Lokasi tujuan (kosong = current dir): " clone_dir
    if [ -z "$clone_dir" ]; then
        gh repo clone "$clone_url"
    else
        gh repo clone "$clone_url" "$clone_dir"
    fi
    echo -e "${GREEN}Clone selesai!${NC}"
}

create_repo() {
    read -p "Nama repo baru: " new_repo
    if [ -z "$new_repo" ]; then
        echo -e "${RED}Nama repo tidak boleh kosong.${NC}"
        return
    fi
    read -p "Deskripsi (opsional): " desc
    read -p "Public (Y) atau Private (N): " pub
    read -p "Inisialisasi README? (y/N): " init_readme
    read -p "Lisensi? (e.g., MIT, ISC, GPL-3.0 - kosong = tidak ada): " license
    
    echo -e "${BLUE}Membuat repo $new_repo...${NC}"
    visibility="private"
    [[ "$pub" =~ ^[Yy]$ ]] && visibility="public"
    
    if [ -n "$license" ]; then
        gh repo create "$new_repo" --description "$desc" --license "$license" --visibility "$visibility"
    elif [[ "$init_readme" =~ ^[Yy]$ ]]; then
        gh repo create "$new_repo" --description "$desc" --add-readme --visibility "$visibility"
    else
        gh repo create "$new_repo" --description "$desc" --visibility "$visibility"
    fi
    echo -e "${GREEN}Repo dibuat!${NC}"
}

delete_repo() {
    read -p "Masukkan nama repo yang ingin dihapus (owner/repo): " del_repo
    if [ -z "$del_repo" ]; then
        echo -e "${RED}Nama repo tidak boleh kosong.${NC}"
        return
    fi
    read -p "Yakin hapus $del_repo? Ketik nama repo secara persis untuk konfirmasi: " confirm
    if [ "$confirm" == "$del_repo" ]; then
        gh repo delete "$del_repo" --yes
        echo -e "${GREEN}Repo dihapus!${NC}"
    else
        echo -e "${RED}Konfirmasi salah. Membatalkan penghapusan.${NC}"
    fi
}

list_branches() {
    get_repo || return
    echo -e "${BLUE}Daftar branch untuk $REPO_NAME:${NC}"
    temp_dir=$(mktemp -d)
    if git clone --depth 1 --single-branch "https://github.com/$REPO_NAME.git" "$temp_dir" 2>/dev/null; then
        cd "$temp_dir"
        git branch -a
        cd - >/dev/null
    else
        echo -e "${RED}Gagal mengambil branch repository.${NC}"
    fi
    rm -rf "$temp_dir"
}

create_branch() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif.${NC}"
        return
    fi
    read -p "Nama branch baru: " branch_name
    if [ -z "$branch_name" ]; then
        echo -e "${RED}Nama branch tidak boleh kosong.${NC}"
        return
    fi
    git switch -c "$branch_name" 2>/dev/null || git checkout -b "$branch_name"
    echo -e "${GREEN}Branch $branch_name dibuat dan aktif!${NC}"
}

switch_branch() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif.${NC}"
        return
    fi
    read -p "Nama branch yang ingin dituju: " branch_name
    if [ -z "$branch_name" ]; then
        echo -e "${RED}Nama branch tidak boleh kosong.${NC}"
        return
    fi
    git switch "$branch_name" 2>/dev/null || git checkout "$branch_name"
    echo -e "${GREEN}Berpindah ke $branch_name${NC}"
}

delete_branch() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif.${NC}"
        return
    fi
    read -p "Nama branch lokal yang ingin dihapus: " branch_name
    if [ -z "$branch_name" ]; then
        echo -e "${RED}Nama branch tidak boleh kosong.${NC}"
        return
    fi
    git branch -D "$branch_name"
    echo -e "${GREEN}Branch lokal $branch_name dihapus!${NC}"
}

commit_changes() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif.${NC}"
        return 1
    fi
    echo -e "${CYAN}Status perubahan:${NC}"
    git status --short
    echo ""
    read -p "Message commit: " commit_msg
    if [ -z "$commit_msg" ]; then
        echo -e "${RED}Message commit tidak boleh kosong.${NC}"
        return 1
    fi
    git add . && git commit -m "$commit_msg"
    echo -e "${GREEN}Commit selesai!${NC}"
}

push_branch() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif.${NC}"
        return 1
    fi
    branch=$(git branch --show-current)
    echo -e "${BLUE}Mengpush branch '$branch' ke origin...${NC}"
    git push -u origin "$branch"
    echo -e "${GREEN}Push selesai!${NC}"
}

list_prs() {
    echo -e "${CYAN}Daftar PR Anda:${NC}"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        gh pr list --state all --json number,title,state,mergedAt \
            -q '.[] | "#\(.number) [\(.state)] \(.title)"'
    else
        get_repo && gh repo set-default "$REPO_NAME" >/dev/null 2>&1
        gh pr list --state all --json number,title,state,mergedAt \
            -q '.[] | "#\(.number) [\(.state)] \(.title)"'
    fi
    echo ""
}

view_pr() {
    get_repo || return
    echo -e "${CYAN}Daftar PR terbuka di $REPO_NAME:${NC}"
    gh pr list --repo "$REPO_NAME" --state open --json number,title,author,createdAt -q '.[] | "#\(.number) \(.title) by \(.author.login)"'
    echo ""
    read -p "Masukkan nomor PR (atau tekan ENTER untuk batal): " pr_num
    if [ -n "$pr_num" ]; then
        gh pr view "$pr_num" --repo "$REPO_NAME" --web
    fi
}

create_pr() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Anda harus berada di dalam direktori repository git aktif untuk membuat PR.${NC}"
        return
    fi
    branch=$(git branch --show-current)
    if [ "$branch" == "main" ] || [ "$branch" == "master" ]; then
        echo -e "${RED}Tidak bisa buat PR dari branch utama ($branch). Buat branch baru terlebih dahulu.${NC}"
        return
    fi
    read -p "Judul PR: " title
    if [ -z "$title" ]; then
        echo -e "${RED}Judul PR tidak boleh kosong.${NC}"
        return
    fi
    read -p "Deskripsi (opsional): " body
    read -p "Target branch (default: main): " target
    target=${target:-main}
    
    if [ -n "$body" ]; then
        gh pr create --title "$title" --body "$body" --base "$target"
    else
        gh pr create --title "$title" --base "$target"
    fi
    echo -e "${GREEN}PR dibuat!${NC}"
}

pr_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}=== Sub-Menu Pull Request ===${NC}"
        echo "1. Daftar PR"
        echo "2. Lihat/Buka PR di Web"
        echo "3. Buat PR Baru"
        echo "4. Cek Status CI PR"
        echo "5. Merge PR"
        echo "0. Kembali ke Menu Utama"
        read -p "Pilih menu PR (0-5): " pr_choice
        case $pr_choice in
            1) list_prs ;;
            2) view_pr ;;
            3) create_pr ;;
            4) 
               echo -e "${CYAN}Checks untuk PR terbuka:${NC}"
               for pr in $(gh pr list --state open --json number -q '.[].number' 2>/dev/null); do
                   status=$(gh pr checks "$pr" --json state -q '.state' 2>/dev/null || echo "unknown")
                   echo "#$pr | Status: $status"
               done
               ;;
            5)
               echo -e "${CYAN}PR yang terbuka:${NC}"
               gh pr list --state open --json number,title -q '.[] | "#\(.number) \(.title)"'
               echo ""
               read -p "Nomor PR yang ingin di-merge: " pr_num
               if [ -n "$pr_num" ]; then
                   read -p "Method merge (merge/squash/rebase): " method
                   method=${method:-merge}
                   gh pr merge "$pr_num" --$method --auto 2>/dev/null || gh pr merge "$pr_num" --$method
                   echo -e "${GREEN}PR #$pr_num berhasil digabungkan!${NC}"
               fi
               ;;
            0) break ;;
            *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
        esac
    done
}

list_issues() {
    echo -e "${CYAN}Pilih state issues:${NC}"
    echo "1. Semua (all)"
    echo "2. Terbuka (open)"
    echo "3. Tertutup (closed)"
    read -p "Pilih 1-3 (default: 1): " choice
    choice=${choice:-1}
    case $choice in
        2) state="open" ;;
        3) state="closed" ;;
        *) state="all" ;;
    esac
    echo ""
    get_repo || return
    echo -e "${CYAN}Issues di $REPO_NAME (${state}):${NC}"
    gh issue list --repo "$REPO_NAME" --state "$state" --json number,title,state,labels,assignees \
        -q '.[] | "#\(.number) [\(.state)] \(.title)"'
}

create_issue() {
    get_repo || return
    read -p "Judul issue: " title
    if [ -z "$title" ]; then
        echo -e "${RED}Judul issue tidak boleh kosong.${NC}"
        return
    fi
    read -p "Deskripsi: " body
    gh issue create --repo "$REPO_NAME" --title "$title" --body "$body"
    echo -e "${GREEN}Issue dibuat!${NC}"
}

close_issue() {
    get_repo || return
    echo -e "${CYAN}Issues terbuka di $REPO_NAME:${NC}"
    gh issue list --repo "$REPO_NAME" --state open --json number,title -q '.[] | "#\(.number) \(.title)"'
    echo ""
    read -p "Nomor issue yang ingin ditutup: " issue_num
    if [ -n "$issue_num" ]; then
        gh issue close --repo "$REPO_NAME" "$issue_num"
        echo -e "${GREEN}Issue #$issue_num ditutup!${NC}"
    fi
}

search_code() {
    read -p "Kata kunci pencarian kode: " query
    if [ -z "$query" ]; then
        echo -e "${RED}Kata kunci tidak boleh kosong.${NC}"
        return
    fi
    read -p "Path penelusuran (kosong = semua): " path
    if [ -n "$path" ]; then
        gh search code "$query" --path="$path"
    else
        gh search code "$query"
    fi
}

actions_menu() {
    get_repo || return
    while true; do
        echo ""
        echo -e "${BLUE}=== Sub-Menu GitHub Actions ($REPO_NAME) ===${NC}"
        echo "1. Daftar Workflow"
        echo "2. Jalankan Workflow"
        echo "3. Riwayat Run Terbaru"
        echo "0. Kembali ke Menu Utama"
        read -p "Pilih menu Actions (0-3): " act_choice
        case $act_choice in
            1)
                echo -e "${CYAN}Workflow Actions:${NC}"
                gh api "repos/$REPO_NAME/actions/workflows" -q '.workflows[] | "\(.id) - \(.name) (\(.path))"'
                ;;
            2)
                echo -e "${CYAN}Workflow tersedia:${NC}"
                gh api "repos/$REPO_NAME/actions/workflows" -q '.workflows[] | "\(.id) - \(.name)"'
                echo ""
                read -p "Workflow ID atau nama file: " workflow
                read -p "Branch target (default: main): " ref
                ref=${ref:-main}
                if [ -n "$workflow" ]; then
                    gh run create "$workflow" --ref "$ref" --repo "$REPO_NAME"
                    echo -e "${GREEN}Workflow berhasil dijalankan!${NC}"
                fi
                ;;
            3)
                echo -e "${CYAN}Action runs terbaru:${NC}"
                gh run list --repo "$REPO_NAME" --limit 10
                ;;
            0) break ;;
            *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
        esac
    done
}

release_menu() {
    get_repo || return
    while true; do
        echo ""
        echo -e "${BLUE}=== Sub-Menu Releases ($REPO_NAME) ===${NC}"
        echo "1. Daftar Release"
        echo "2. Buat Release Baru"
        echo "0. Kembali ke Menu Utama"
        read -p "Pilih menu Release (0-2): " rel_choice
        case $rel_choice in
            1)
                echo -e "${CYAN}Daftar release:${NC}"
                gh release list --repo "$REPO_NAME"
                ;;
            2)
                read -p "Tag version (misal: v1.0.0): " tag
                if [ -z "$tag" ]; then
                    echo -e "${RED}Tag version tidak boleh kosong.${NC}"
                    continue
                fi
                read -p "Judul release (kosong = auto): " title
                read -p "Deskripsi / Notes: " notes
                read -p "Target branch/commit (default: main): " ref
                ref=${ref:-main}
                
                if [ -n "$title" ]; then
                    gh release create "$tag" --repo "$REPO_NAME" --title "$title" --notes "$notes" "$ref"
                else
                    gh release create "$tag" --repo "$REPO_NAME" --notes "$notes" "$ref"
                fi
                echo -e "${GREEN}Release $tag berhasil dibuat!${NC}"
                ;;
            0) break ;;
            *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
        esac
    done
}

show_info() {
    echo -e "${CYAN}Informasi akun GitHub:${NC}"
    gh api user -q '"Login: \(.login)\nName: \(.name)\nPublic repos: \(.public_repos)\nFollowers: \(.followers)\nFollowing: \(.following)"'
    echo ""
    echo -e "${CYAN}Status autentikasi:${NC}"
    gh auth status
}

show_help() {
    echo -e "${GREEN}=== GitHub Interactive Menu ===${NC}"
    echo "Menu ini menyediakan operasi GitHub via gh CLI."
    echo "Pastikan repository aktif atau pilih repo saat diminta."
    echo "Gunakan perintah: bash ~/Github/gh-menu.sh"
    echo ""
}

main_menu() {
    check_auth || true
    while true; do
        echo ""
        echo -e "${BLUE}=======================================${NC}"
        echo -e "${BLUE}   Menu Utama - GitHub Operations    ${NC}"
        echo -e "${BLUE}=======================================${NC}"
        echo ""
        echo " 1. Cek Autentikasi GitHub"
        echo " 2. Daftar Semua Repository"
        echo " 3. Clone Repository Baru"
        echo " 4. Buat Repository Baru"
        echo " 5. Hapus Repository"
        echo " 6. Daftar Branch di Repo"
        echo " 7. Buat Branch Baru"
        echo " 8. Switch Branch"
        echo " 9. Hapus Branch Lokal"
        echo "10. Commit & Push Perubahan"
        echo "11. Kelola Pull Request (PR)"
        echo "12. Daftar Issues"
        echo "13. Buat Issue Baru"
        echo "14. Tutup Issue"
        echo "15. Search Kode"
        echo "16. Kelola GitHub Actions"
        echo "17. Kelola Releases"
        echo "18. Informasi Akun"
        echo "19. Bantuan / Panduan"
        echo " 0. Keluar"
        echo ""
        read -p "Pilih menu (0-19): " choice
        
        case $choice in
            1) check_auth ;;
            2) list_repos ;;
            3) clone_repo ;;
            4) create_repo ;;
            5) delete_repo ;;
            6) list_branches ;;
            7) create_branch ;;
            8) switch_branch ;;
            9) delete_branch ;;
            10) commit_changes && push_branch ;;
            11) pr_menu ;;
            12) list_issues ;;
            13) create_issue ;;
            14) close_issue ;;
            15) search_code ;;
            16) actions_menu ;;
            17) release_menu ;;
            18) show_info ;;
            19) show_help ;;
            0) echo -e "${GREEN}Terima kasih! Sampai jumpa bos.${NC}"; exit 0 ;;
            *) echo -e "${RED}Pilihan tidak valid. Silakan pilih 0-19.${NC}" ;;
        esac
    done
}

show_help
main_menu
