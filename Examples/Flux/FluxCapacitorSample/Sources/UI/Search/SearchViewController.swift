//
//  SearchViewController.swift
//  FluxCapacitorSample
//
//  Created by marty-suzuki on 2017/08/01.
//  Copyright © 2017年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import NoticeObserveKit

final class SearchViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var counterLabel: UILabel!
    
    private let searchBar: UISearchBar = UISearchBar(frame: .zero)
    private let action = UserAction()
    private let store = UserStore.instantiate()
    private let disposeBag = DisposeBag()
    private let dataSource = SearchViewDataSource()
    private var pool = NoticeObserverPool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = searchBar
        searchBar.placeholder = "Input user name"
        tableView.contentInset.top = 44
        
        dataSource.configure(with: tableView)
        observeUI()
        observeStore()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observeKeyboard()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if searchBar.isFirstResponder {
            searchBar.resignFirstResponder()
        }
        pool = NoticeObserverPool()
    }

    private func observeKeyboard() {
        UIKeyboardWillShow.observe { [weak self] in
            self?.view.layoutIfNeeded()
            let extra = self?.tabBarController?.tabBar.bounds.height ?? 0
            self?.tableViewBottomConstraint.constant = $0.frame.size.height - extra
            UIView.animate(withDuration: $0.animationDuration, delay: 0, options: $0.animationCurve, animations: {
                self?.view.layoutIfNeeded()
            }, completion: nil)
        }
        .disposed(by: pool)

        UIKeyboardWillHide.observe { [weak self] in
            self?.view.layoutIfNeeded()
            self?.tableViewBottomConstraint.constant = 0
            UIView.animate(withDuration: $0.animationDuration, delay: 0, options: $0.animationCurve, animations: {
                self?.view.layoutIfNeeded()
            }, completion: nil)
        }
        .disposed(by: pool)
    }

    private func observeUI() {
        searchBar.rx.text.orEmpty
            .debounce(0.5, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] text in
                self?.action.invoke(.removeAllUsers)
                self?.action.invoke(.lastPageInfo(nil))
                self?.action.invoke(.lastSearchQuery(""))
                self?.action.invoke(.userTotalCount(0))
                self?.action.fetchUsers(withQuery: text, after: nil)
            })
            .disposed(by: disposeBag)

        Observable.merge(searchBar.rx.cancelButtonClicked.asObservable(),
                         searchBar.rx.searchButtonClicked.asObservable())
            .bind(to: resignFirstResponder)
            .disposed(by: disposeBag)

        searchBar.rx.textDidBeginEditing
            .map { true }
            .bind(to: showsCancelButton)
            .disposed(by: disposeBag)

        searchBar.rx.textDidEndEditing
            .map { false }
            .bind(to: showsCancelButton)
            .disposed(by: disposeBag)
    }

    private func observeStore() {
        Observable.merge(store.users.map { _ in },
                         store.isUserFetching.map { _ in })
            .bind(to: reloadData)
            .disposed(by: disposeBag)

        store.selectedUser
            .filter { $0 != nil }
            .map { _ in  }
            .bind(to: showUserRepository)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(store.users, store.userTotalCount)
            .map { "\($0.count) / \($1)" }
            .observeOn(MainScheduler.instance)
            .bind(to: counterLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
    private var reloadData: AnyObserver<Void> {
        return Binder(self) { me, _ in
            me.tableView.reloadData()
        }.asObserver()
    }
    
    private var resignFirstResponder: AnyObserver<Void> {
        return Binder(self) { me, _ in
            me.searchBar.resignFirstResponder()
        }.asObserver()
    }
    
    private var showsCancelButton: AnyObserver<Bool> {
        return Binder(self) { me, showsCancelButton in
            me.searchBar.showsScopeBar = showsCancelButton
        }.asObserver()
    }

    private var showUserRepository: AnyObserver<Void> {
        return Binder(self) { me, _ in
            guard let vc = UserRepositoryViewController() else { return }
            me.navigationController?.pushViewController(vc, animated: true)
        }.asObserver()
    }
}
